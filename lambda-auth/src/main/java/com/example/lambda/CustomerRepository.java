package com.example.lambda;

import java.sql.*;

public class CustomerRepository {

    private static final String URL = System.getenv("DB_URL");
    private static final String USER = System.getenv("DB_USER");
    private static final String PASSWORD = System.getenv("DB_PASSWORD");

    public boolean existsByCpf(String cpf) {
        String sql = "SELECT 1 FROM customers WHERE cpf = ? LIMIT 1";

        try (Connection conn = DriverManager.getConnection(URL, USER, PASSWORD);
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, cpf);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next();
            }

        } catch (SQLException e) {
            throw new RuntimeException("Erro ao consultar o banco", e);
        }
    }
}
