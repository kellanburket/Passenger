//
//  HttpRequest.swift
//  Pods
//
//  Created by Kellan Cummings on 6/11/15.
//
//

import Foundation
import UIKit

internal typealias HttpResponseHandler = (NSData!, NSURLResponse!, NSError!) -> ()

internal protocol HttpSuccessDelegate {
    func actionHasSucceededWhereOthersHaveFailed()
    func actionHasFailedWhereOthersHaveSucceeded()
}

internal protocol HttpResultsDelegate {
    func resultsHaveBeenFetched(data: NSData!)
}

/**
    Represents an Http Request

    Currently only visible to expose class helper methods
*/
public class HttpRequest {

    private var authorizationService: AuthorizationService?
    private var handler: HttpResponseHandler
    
    internal var headers = [String:String]()
    internal var parameters = [String:AnyObject]()

    internal var baseUrl: NSURL
    
    var url: String {
        return baseUrl.absoluteString!
    }
    
    var method: HttpMethod
    
    var contentType: String? {
        get {
            return headers["Content-Type"]
        }
        set(contentType) {
            headers["Content-Type"] = contentType
        }
    }

    var accept: String? {
        get {
            return headers["Accept"]
        }
        set(contentType) {
            headers["Accept"] = contentType
        }
    }
    
    var onComplete: HttpResponseHandler {
        return handler
    }
  
    init(URL: NSURL, method: HttpMethod, params: [String: AnyObject] = [String: AnyObject](), handler: HttpResponseHandler = { data, response, error in }) {
        self.baseUrl = URL
        self.method = method
        self.parameters = params
        self.handler = handler
        
        self.headers = [
            "Content-Type": HttpMediaType.FormEncoded.description,
            "Accept": HttpMediaType.Json.description
        ]
    }

    convenience init(URL: NSURL, method: HttpMethod, handler: HttpResponseHandler = { data, response, url in }) {
        self.init(URL: URL, method: method, params: [String: AnyObject](), handler: handler)
    }
    
    convenience init(URL: NSURL, method: HttpMethod, params: [String:AnyObject], handler: NSData! -> Void) {
        self.init(URL: URL, method: method, params: params, handler: HttpRequest.getDefaultCompletionHandler(handler))
    }
    
    convenience init(URL: NSURL, method: HttpMethod, params: [String:AnyObject], delegate: HttpResultsDelegate) {
        self.init(URL: URL, method: method, params: params, handler: HttpRequest.getDefaultCompletionHandler(delegate))
    }
    
    convenience init(URL: NSURL, method: HttpMethod, params: [String:AnyObject], delegate: HttpSuccessDelegate) {
        self.init(URL: URL, method: method, params: params, handler: HttpRequest.getDefaultCompletionHandler(delegate))
    }
    
    convenience init(URL: NSURL, method: HttpMethod, delegate: HttpResultsDelegate) {
        self.init(URL: URL, method: method, params: [String:AnyObject](), handler: HttpRequest.getDefaultCompletionHandler(delegate))
    }
    
    convenience init(URL: NSURL, method: HttpMethod, delegate: HttpSuccessDelegate) {
        self.init(URL: URL, method: method, params: [String:AnyObject](), handler: HttpRequest.getDefaultCompletionHandler(delegate))
    }

    convenience init(URL: NSURL, method: HttpMethod, handler: NSData! -> Void) {
        self.init(URL: URL, method: method, params: [String:AnyObject](), handler: HttpRequest.getDefaultCompletionHandler(handler))
    }

    func authenticate(service: AuthorizationService) {
        self.authorizationService = service
    }
    
    func prepare(onComplete: (NSMutableURLRequest) -> ()) {
        //println("Preparing Request")
        if let service = self.authorizationService {
            //println("Prepping Authorization Service \(service)")
            service.setSignature(self.baseUrl, parameters: self.parameters, method: method.description) {
                //println("Signature has been set")
                //println("Parameters: \(self.parameters)")
                
                var request = self.generateRequestObject()
                
                service.setHeader(self.baseUrl, request: &request)
                
                onComplete(request)
            }
        } else {
            //println("Returning Generated Request Object")
            onComplete(self.generateRequestObject())
        }
    }
    
    class func parseQueryString(data: NSData, encoding: UInt = NSUTF8StringEncoding) -> [String: AnyObject] {
        var arr = [String: AnyObject]()
        
        if let urlString = data.stringify(encoding: encoding) {
            //println("URL STRING: \(urlString)")
            return self.parseQueryString(urlString)
        }
        
        return arr
    }
    
    /*
        Parse a URL query string
    
        :param: url self-explanatory
        
        :returns:   a dictionary of key value pairs
    */
    public class func parseQueryString(url: NSURL) -> [String: AnyObject] {
        var arr = [String: AnyObject]()
        
        if let urlString = url.absoluteString {
            var urlParts = urlString.split("?")
            if urlParts.count > 1 {
                return self.parseQueryString(urlParts[1])
            }
        }
        
        return arr
    }
    
    class func parseQueryString(query: String) -> [String: AnyObject] {
        var arr = [String: AnyObject]()

        var keyValuePairs = query.split("&")
        //println("keyValuePairs: \(keyValuePairs)")
        
        for keyValuePair in keyValuePairs {
            var keyValuePairArr = keyValuePair.split("=")
            if keyValuePairArr.count == 2 {
                arr[keyValuePairArr[0]] = keyValuePairArr[1]
            }
        }
        
        return arr
    }
    
    func setHeaders(headers: [String: String]) {
        for (header, value) in headers {
            setHeader(header, value: value)
        }
    }
    
    func setHeader(header: String, value: String) {
        self.headers[header] = value
    }

    private func setRequestHeaders(inout request: NSMutableURLRequest) {
        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }
    }
            
    private func generateRequestObject() -> NSMutableURLRequest {

        if method == HttpMethod.Get {
            baseUrl = NSURL(string: getAbsoluteURL())!
        }

        var request = NSMutableURLRequest(
            URL: baseUrl,
            cachePolicy: .ReturnCacheDataElseLoad,
            timeoutInterval: 120
        )
        
        request.HTTPMethod = method.description
        request.HTTPShouldHandleCookies = false

        setRequestHeaders(&request)

        if method != HttpMethod.Get {
            prepareBody(&request)
        }

        return request
    }
    
    private func sortParamaters() {
        var newParameters = [String: AnyObject]()
        var keys = [String](parameters.keys)
        keys.sort({ return $0 < $1 })
        
        for key in keys {
            newParameters[key] = parameters[key]!
        }
        
        parameters = newParameters
    }
    
    private func getAbsoluteURL() -> String {
        var urlString = baseUrl.absoluteString!
        var paramString = buildParamString()
        return "\(urlString)\(paramString)"
    }
    
    internal func prepareBody(inout request: NSMutableURLRequest) {
        
        var bodyString = ""
        
        for (k, v) in parameters {
            var key = k.percentEncode()
            var value = "\(v)".gsub(" ", "+").percentEncode(ignore: ["+"])
            bodyString += "\(key)=\(value)&"
        }
        bodyString = bodyString.rtrim("& ")
        
        //println(bodyString)
        request.HTTPBody = bodyString.dataUsingEncoding(NSUTF8StringEncoding)
    }
    
    private func buildParamString() -> String {
        if count(parameters) > 0 {
            var paramString = "?"
            
            var keys = [String](parameters.keys)
            keys.sort({ return $0 < $1 })
            
            for key in keys {
                var value = "\(parameters[key]!)"
                paramString += key.percentEncode()  + "=" + value.percentEncode(ignore: ["+", "-"])  + "&"
            }
            
            return paramString.rtrim("&")
        } else {
            return ""
        }
    }
    
    private class func getDefaultCompletionHandler(delegate: HttpResultsDelegate) -> HttpResponseHandler {
        return getDefaultCompletionHandler { data in
            delegate.resultsHaveBeenFetched(data)
        }
    }
    
    private class func getDefaultCompletionHandler(delegate: HttpSuccessDelegate) -> HttpResponseHandler {
        return { data, response, error in
            
            if let r = response as? NSHTTPURLResponse  {
                var statusCode = r.statusCode
                switch statusCode {
                    case 200:
                        delegate.actionHasSucceededWhereOthersHaveFailed()
                    default:
                        println(response)
                        delegate.actionHasFailedWhereOthersHaveSucceeded()
                    }
            } else {
                println(error)
                println(response)
                delegate.actionHasFailedWhereOthersHaveSucceeded()
            }
        }
    }
    
    internal class func getDefaultCompletionHandler(handler: (NSData!) -> ()) -> HttpResponseHandler {
        return { data, response, error in
            
            if let r = response as? NSHTTPURLResponse {
                var statusCode = r.statusCode
                switch statusCode {
                    case 200:
                        //println("\t(200)\tSuccess")
                        //if let data = data.stringify() { //Log.d(data) }
                        handler(data)
                    case 401:
                        println("\t(401)\tUnauthorized")
                        handler(nil)
                    case 403:
                        println("\t(403)\tResource Forbidden")
                        //AlertDialogueController("Resource Forbidden", "You are not permitted to access the selected resource.").present()
                        handler(nil)
                    case 404:
                        println("\t(404)\tResource Not Found")
                        //AlertDialogueController("Resource Not Found", "The selected resource cannot be found.").present()
                        handler(nil)
                    case 408:
                        println("\t(408)\tNetwork Timeout")
                        //AlertDialogueController("Network Timeout", "The network timed out while attempting to complete your request.").present()
                        handler(nil)
                    case 415:
                        println("\t(415)\tUnsupported Media Type")
                        //AlertDialogueController("Unsupported Media Type", "You are attempting to upload an unsupported media type. The requested action cannot be completed.").present()
                        handler(nil)
                    case 500:
                        println("\t(500)\tServer Error")
                        handler(nil)
                    default:
                        //AlertDialogueController("Something went wrong.", "Please try your request again later.").present()
                        println("\t\(statusCode)\t\(response)")
                        handler(nil)
                }
            } else {
                println(error)
                handler(nil)
                //AlertDialogueController("Network Connectivity Issue", "There was a problem establishing a connection to the server.").present()
            }

            //UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }
}