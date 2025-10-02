package com.example.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.HashMap;
import java.util.Map;

public class Handler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    private final CustomerRepository repository = new CustomerRepository();
    private final JwtUtil jwtUtil = new JwtUtil();
    private final CpfValidator cpfValidator = new CpfValidator();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> input, Context context) {
        try {
            // Entrada enviada via API Gateway
            Map<String, Object> bodyInput = objectMapper.readValue((String) input.get("body"), Map.class);
            String cpf = (String) bodyInput.get("cpf");

            if (cpf == null || cpf.isEmpty()) {
                return buildResponse(400, Map.of("error", "CPF é obrigatório"));
            }

            // valida formato e dígitos
            if (!cpfValidator.isValid(cpf)) {
                return buildResponse(400, Map.of("error", "CPF inválido"));
            }

            boolean exists = repository.existsByCpf(cpf);
            String token = jwtUtil.generateToken(cpf, exists);

            Map<String, Object> responseBody = new HashMap<>();
            responseBody.put("cpf", cpf);
            responseBody.put("registered", exists);
            responseBody.put("token", token);

            return buildResponse(200, responseBody);

        } catch (Exception e) {
            return buildResponse(500, Map.of("error", "Erro interno: " + e.getMessage()));
        }
    }

    private Map<String, Object> buildResponse(int statusCode, Object body) {
        try {
            return Map.of(
                    "statusCode", statusCode,
                    "headers", Map.of("Content-Type", "application/json"),
                    "body", objectMapper.writeValueAsString(body)
            );
        } catch (Exception e) {
            return Map.of(
                    "statusCode", 500,
                    "body", "{\"error\":\"Falha ao serializar resposta\"}"
            );
        }
    }
}
