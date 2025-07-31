/**
 * @ Author: Ahmed EL Qori
 * @ Create Time: 2025-07-31 10:50:05
 * @ Modified by: Your name
 * @ Modified time: 2025-07-31 14:34:21
 * @ Description: Create Interceptor For request and response
 */
public with sharing class OAuthService {
    public static String getAccessToken() {
        HttpRequest                     req;
        HttpResponse                    res;
        Http                            http;

        req = new HttpRequest();
        setupOAuth(req);
        http = new Http();
        res = http.send(req);
        if (res.getStatusCode() == 200) return parseResponse(res);
        generateErrorMessage(res.getStatusCode());
        return null;
    }

    public static void authorizeRequest(HttpRequest req) {
        try {
            String token = getAccessToken();
            req.setHeader('Authorization', 'Bearer ' + token);
        } catch (Exception e) {
            System.debug(e);
        }
    }

    public static HttpResponse EnhancedFetch(String method, String callout,
            String path, Map<String, String> headers, Map<String, Object> payload) {
        try {
            HttpResponse    res;
            HttpRequest     req;
            Http            http;
            
            req = new HttpRequest();
            setEndPoint(req, callout, path);
            setMethod(req, method);
            setContentType(req, headers);
            setHeaders(req, headers);
            authorizeRequest(req);
            setBody(req, payload, method);
            req.setTimeout(120000);
            http = new Http();
            res = http.send(req);
            return res;
        } catch (Exception e) {
            System.debug('EnhancedFetch Error: ' + e.getMessage());
            throw new CalloutException('HTTP Request failed: ' + e.getMessage());
        }
    }

    private static void setupOAuth(HttpRequest req)
    {
        List<EnvironmentSetting__mdt>   env;
        Map<String, Object>             payload;

        env = EnvironmentSetting__mdt.getAll().values();
        payload = new Map<String, Object>{
            'clientId' => env[0].client_id__c,
            'clientSecret' => env[0].client_secret__c
        };
        req.setEndpoint(env[0].Api_URL__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
    } 

    private static void setEndPoint(HttpRequest req, String callout, String path)
    {
        String  endpoint;

        endpoint = callout;
        if (String.isNotBlank(path))
            endpoint += (callout.endsWith('/') || path.startsWith('/')) ? path : '/' + path;
        req.setEndpoint(endpoint);
    }

    private static void setMethod(HttpRequest req, String method)
    {
        req.setMethod(method.toUpperCase());
    }
    
    private static void setContentType(HttpRequest req, Map<String, String> headers)
    {
        if (headers == null || !headers.containsKey('Content-Type'))
            req.setHeader('Content-Type', 'application/json');
    }

    private static void setHeaders(HttpRequest req, Map<String, String> headers)
    {
        if (headers != null && !headers.isEmpty()) {
            for (String headerKey : headers.keySet()) {
                req.setHeader(headerKey, headers.get(headerKey));
            }
        }
    }

    private static void setBody(HttpRequest req, Map<String, Object> payload, String method)
    {
        if (payload != null && !payload.isEmpty() && 
            (method.equalsIgnoreCase('POST') || method.equalsIgnoreCase('PUT') || method.equalsIgnoreCase('PATCH'))) {
            req.setBody(JSON.serialize(payload));
        }
    }

    private static String parseResponse(HttpResponse res)
    {
        return  (String) (((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('accessToken'));
    }

    private static void generateErrorMessage(Integer statusCode) {
        if (statusCode == 401)
            throw new CalloutException('Unauthorized access. Invalid credentials provided.');
        if (statusCode == 422)
            throw new CalloutException('Validation error. Missing or invalid input parameters.');
        throw new CalloutException('Unexpected response with status code: ' + statusCode);
    }
}


