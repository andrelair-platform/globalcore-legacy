package com.globalcorp.gcore.endpoint;

import com.globalcorp.gcore.dao.PolicyDao;
import com.globalcorp.gcore.ws.CreatePolicyRequest;
import com.globalcorp.gcore.ws.CreatePolicyResponse;
import com.globalcorp.gcore.ws.GetPolicyRequest;
import com.globalcorp.gcore.ws.GetPolicyResponse;
import org.springframework.ws.server.endpoint.annotation.Endpoint;
import org.springframework.ws.server.endpoint.annotation.PayloadRoot;
import org.springframework.ws.server.endpoint.annotation.RequestPayload;
import org.springframework.ws.server.endpoint.annotation.ResponsePayload;

/** The SOAP endpoint — the ONLY sanctioned way in/out of GlobalCore for the policy domain. */
@Endpoint
public class PolicyEndpoint {

    private static final String NS = "http://globalcorp.com/gcore/policy";
    private final PolicyDao dao;

    public PolicyEndpoint(PolicyDao dao) {
        this.dao = dao;
    }

    @PayloadRoot(namespace = NS, localPart = "GetPolicyRequest")
    @ResponsePayload
    public GetPolicyResponse getPolicy(@RequestPayload GetPolicyRequest req) {
        return dao.getPolicy(req.getPolNo());
    }

    @PayloadRoot(namespace = NS, localPart = "CreatePolicyRequest")
    @ResponsePayload
    public CreatePolicyResponse createPolicy(@RequestPayload CreatePolicyRequest req) {
        return dao.createPolicy(req);
    }
}
