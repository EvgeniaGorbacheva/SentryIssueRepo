//
//  SentryWrapper.swift
//  SentryIssueRepo
//
//  Created by Evgenia Gorbacheva on 29/07/2024.
//

import Sentry

public class SentryWrapper {

    public init() {
        let sentryOptions = Options()
        
        sentryOptions.dsn = "https://3f6b7c8f890f9effc523308aae457446@o4505760604356608.ingest.sentry.io/4505760605339648"
        sentryOptions.attachViewHierarchy = false
        
        sentryOptions.initialScope = { scope in
            let user = User()
            user.username = Bundle.main.bundleIdentifier
            
            return scope
        }
        
        sentryOptions.beforeSend = { event in
            print(event.eventId.sentryIdString)
            return event
        }
        
        SentrySDK.start(options: sentryOptions)
    }
}

