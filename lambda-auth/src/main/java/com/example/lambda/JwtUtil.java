package com.example.lambda;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;

import java.security.Key;
import java.util.Date;

public class JwtUtil {

    private static final Key key = Keys.secretKeyFor(SignatureAlgorithm.HS256);

    public String generateToken(String cpf, boolean existsInDb) {
        long expiration = 1000 * 60 * 60; // 1 hora

        return Jwts.builder()
                .setSubject(cpf)
                .setIssuer("lambda-auth")
                .claim("registered", existsInDb)  // flag se existe no banco
                .setExpiration(new Date(System.currentTimeMillis() + expiration))
                .signWith(key)
                .compact();
    }
}
