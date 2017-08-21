//
//  HomeController.swift
//  Panther
//
//  Created by Ke Ma on 16/08/2017.
//  Copyright © 2017 wme. All rights reserved.
//

import UIKit
import KeychainAccess

class HomeController: UIViewController
{
  @IBOutlet weak var webView: UIWebView!
  @IBOutlet weak var pageLoadingProgress: UIProgressView!
  
  var username: String?
  var password: String?
  
  var requestedUrl: URL?
  var loadedUrl: URL?
  
  // Private functions
  private func setupWebView()
  {
    webView.delegate = self
    webView.loadRequest(URLRequest(url: URL(string: "https://panther.wmeimg.com")!))
  }
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    self.setupWebView()
  }
}

extension HomeController: UIWebViewDelegate
{
  
  func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool
  {
    if navigationType == .formSubmitted &&
      request.url?.absoluteString != "https://panther.wmeimg.com/Search"
    {
      if let httpBody = request.httpBody
      {
        let bodyStr = String(data: httpBody, encoding: .utf8)
        let valuesArr = bodyStr?.components(separatedBy: "&")
        
        let usernameArr = valuesArr?[0].components(separatedBy: "=")
        self.username = usernameArr?[1].removingPercentEncoding
        
        let passwordArr = valuesArr?[1].components(separatedBy: "=")
        self.password = passwordArr?[1].removingPercentEncoding
        
      }
    }
    
    return true
  }
  
  func webViewDidStartLoad(_ webView: UIWebView) {
    self.pageLoadingProgress.alpha = 1.0
    self.pageLoadingProgress.setProgress(0.1, animated: false)
    
    self.requestedUrl = webView.request?.mainDocumentURL
  }
  
  func webViewDidFinishLoad(_ webView: UIWebView) {
    
    self.pageLoadingProgress.setProgress(1.0, animated: true)
    UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseInOut, animations: {
      self.pageLoadingProgress.alpha = 0.0
    }) { (finished:Bool) in
      self.pageLoadingProgress.progress = 0.0
    }
    
    self.title = webView.pageTitle
    
    self.loadedUrl = webView.request?.mainDocumentURL
    
    // To detect user on ADFS Server
    if loadedUrl?.host != requestedUrl?.host &&
      loadedUrl?.host == "sts1.wmeimg.com"
    {
      //print("redirect to adfs")
      let keychain = Keychain(service: "com.img.panther")
      
      if keychain["credentialsAreStored"] == "yes" {
        // If user if authenticated from touch id
        
        let username = keychain["username"]
        
        DispatchQueue.global().async {
          do {
            let password = try keychain.authenticationPrompt("Authenticate to login").get("password")
            
            if username != nil && password != nil {
              
              DispatchQueue.main.async {
                webView.stringByEvaluatingJavaScript(from: "document.getElementById('userNameInput').value='\(username!)';document.getElementById('passwordInput').value='\(password!)'")
              }
            }
          
          } catch let error {
            // Error handling if needed...
            print(error.localizedDescription)
          }
        }
      }
      

    }
    // to detect user login successfully
    else if loadedUrl?.host != requestedUrl?.host &&
      loadedUrl?.host == "panther.wmeimg.com"
    {
      let keychain = Keychain(service: "com.img.panther")
      
      if keychain["credentialsAreStored"] != "yes"
      {
        // Save username password to keychain
        
        keychain["username"] = username!
        DispatchQueue.global().async {
          do {
            try keychain
              .authenticationPrompt("Verify your Touch ID to save your login details")
              .accessibility(.whenPasscodeSetThisDeviceOnly, authenticationPolicy: .userPresence).set(self.password!, key: "password")
            //
            try keychain.set("yes", key: "credentialsAreStored")
          } catch (Status.userCanceled) {
            // Catch user touched Cancel button
          
          } catch let error {
            // Error handling if needed...
            print(error.localizedDescription)
          }
        }
      }

    }// end else

  }
}

extension UIWebView
{
  var pageTitle: String? {
    
    guard let title = self.stringByEvaluatingJavaScript(from: "document.title") else {
      return nil
    }
    
    return title
  }
}
