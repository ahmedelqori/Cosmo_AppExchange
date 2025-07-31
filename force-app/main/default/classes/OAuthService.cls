/**
 * @ Author: Ahmed EL  Qori
 * @ Create Time: 2025-07-31 10:50:05
 * @ Modified by: Your name
 * @ Modified time: 2025-07-31 12:00:18
 * @ Description: Create Interceptor For request and response
 */
public with sharing class OAuthService {
    public static String getAccessToken() {
        EnvironmentSetting__mdt env = [
            SELECT Id, client_id__c, client_secret__c, Api_URL__c 
            FROM EnvironmentSetting__mdt
            LIMIT 1
        ];

        HttpRequest req = new HttpRequest();
        req.setEndpoint(env.Api_URL__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        Map<String, Object> payload = new Map<String, Object>{
            'clientId' => env.client_id__c,
            'clientSecret' => env.client_secret__c
        };
        req.setBody(JSON.serialize(payload));
        Http http = new Http();
        HttpResponse res = http.send(req);

        switch on res.getStatusCode()  {
            when 200 {
                Map<String, Object> tokenResponse = 
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) tokenResponse.get('accessToken');
            }
            when 401 {
                System.debug('Unauthorized: ' + res.getBody());
                throw new CalloutException('Unauthorized access. Invalid credentials provided.');
            }
            when 422 {
                System.debug('Validation Error: ' + res.getBody());
                throw new CalloutException('Validation error. Missing or invalid input parameters.');
            }
            when else {
                System.debug('Unexpected status code ' + res.getStatusCode() + ': ' + res.getBody());
                throw new CalloutException('Unexpected response: ' + res.getBody());
            }
        }
    }
    public static void authorizeRequest(HttpRequest req) {
        try {
            String token = getAccessToken();
            req.setHeader('Authorization', 'Bearer ' + token);
        } catch (Exception e) {
            System.debug(e);
        }
    }
    public static HttpResponse EnhancedFetch(String method, String callout, String path, Map<String, String> headers, Map<String, Object> payload) {
        try {
            HttpRequest req = new HttpRequest();
            String endpoint = callout;
            if (String.isNotBlank(path)) {
                endpoint += (callout.endsWith('/') || path.startsWith('/')) ? path : '/' + path;
            }
            req.setEndpoint(endpoint);
            req.setMethod(method.toUpperCase());
            if (headers == null || !headers.containsKey('Content-Type')) {
                req.setHeader('Content-Type', 'application/json');
            }
            if (headers != null && !headers.isEmpty()) {
                for (String headerKey : headers.keySet()) {
                    req.setHeader(headerKey, headers.get(headerKey));
                }
            }
            authorizeRequest(req);
            if (payload != null && !payload.isEmpty() && 
                (method.equalsIgnoreCase('POST') || method.equalsIgnoreCase('PUT') || method.equalsIgnoreCase('PATCH'))) {
                req.setBody(JSON.serialize(payload));
            }
            req.setTimeout(120000);
            Http http = new Http();
            HttpResponse res = http.send(req);
            return res;
        } catch (Exception e) {
            System.debug('EnhancedFetch Error: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new CalloutException('HTTP Request failed: ' + e.getMessage());
        }
    }
}


