package com.globalcorp.gcore.config;

import org.springframework.boot.web.servlet.ServletRegistrationBean;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;
import org.springframework.ws.config.annotation.EnableWs;
import org.springframework.ws.config.annotation.WsConfigurerAdapter;
import org.springframework.ws.transport.http.MessageDispatcherServlet;
import org.springframework.ws.wsdl.wsdl11.DefaultWsdl11Definition;
import org.springframework.xml.xsd.SimpleXsdSchema;
import org.springframework.xml.xsd.XsdSchema;

/** SOAP endpoint wiring. WSDL is served at /ws/policy.wsdl ; the service at /ws. */
@EnableWs
@Configuration
public class WebServiceConfig extends WsConfigurerAdapter {

    @Bean
    public ServletRegistrationBean<MessageDispatcherServlet> messageDispatcherServlet(ApplicationContext ctx) {
        MessageDispatcherServlet servlet = new MessageDispatcherServlet();
        servlet.setApplicationContext(ctx);
        servlet.setTransformWsdlLocations(true);
        return new ServletRegistrationBean<>(servlet, "/ws/*");
    }

    @Bean(name = "policy")
    public DefaultWsdl11Definition defaultWsdl11Definition(XsdSchema policySchema) {
        DefaultWsdl11Definition wsdl = new DefaultWsdl11Definition();
        wsdl.setPortTypeName("PolicyPort");
        wsdl.setLocationUri("/ws");
        wsdl.setTargetNamespace("http://globalcorp.com/gcore/policy");
        wsdl.setSchema(policySchema);
        return wsdl;
    }

    @Bean
    public XsdSchema policySchema() {
        return new SimpleXsdSchema(new ClassPathResource("xsd/policy.xsd"));
    }
}
