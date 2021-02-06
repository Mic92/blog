+++
title = "Global Request Management With Restkit"
date = "2013-09-03"
slug = "2013/09/03/global-request-management-with-restkit"
Categories = []
+++

For our latest iOS app we are using [RestKit Framework](http://restkit.org), which is a really great and advanced library to communicate to your REST API.

When you have lots of requests in different areas of your project, you may want to have a global handling for failure events.
For example how an Login View, if any of the requests gives you an 401 (Unauthorized) status code.

In RestKit 0.20 they introduced the oppertunity to register your own `RKObjectRequestOperation`, which is the common way to do this.

So at first you create a subclass of `RKObjectRequestOperation`, let's call it `CustomRKObjectRequestOperation`

```objective-c

#import "RKObjectRequestOperation.h"

@interface CustomRKObjectRequestOperation : RKObjectRequestOperation

@end

@implementation CustomRKObjectRequestOperation

- (void)setCompletionBlockWithSuccess:(void ( ^ ) ( RKObjectRequestOperation *operation , RKMappingResult *mappingResult ))success failure:(void ( ^ ) ( RKObjectRequestOperation *operation , NSError *error ))failure
{
    [super setCompletionBlockWithSuccess:^void(RKObjectRequestOperation *operation , RKMappingResult *mappingResult) {
        if (success) {
            success(operation, mappingResult);
        }
        
    }failure:^void(RKObjectRequestOperation *operation , NSError *error) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"connectionFailure" object:operation];
        
        if (failure) {
            failure(operation, error);
        }
        
    }];
}

@end

```
This is the point where we overwrite the method which sets the completion and failure block.
I use the Observer Pattern (`NSNotificationCenter`) to notify about connectionFailures. ([Learn more about NSNotificationCenter](http://mobile.tutsplus.com/tutorials/iphone/ios-sdk_nsnotificationcenter/))  

Of course we need to tell RestKit to use our custom `RKObjectRequestOperation` class. You can do this by adding this line to you RestKit configuration:
```objective-c
[[RKObjectManager sharedManager] registerRequestOperationClass:[CustomRKObjectRequestOperation class]];
```


Now we need a class where we listen to the failure notifications. You can choose any of your class, I use the AppDelegate for this.
```objective-c
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionFailedWithOperation:) name:@"connectionFailure" object:nil];
```

As you should know, the `connectionFailedWithOperation:` is called when a connection failure occures.
```objective-c
- (void)connectionFailedWithOperation:(NSNotification *)notification
{
    RKObjectRequestOperation *operation = (RKObjectRequestOperation *)notification.object;
    if (operation) {
        
        NSInteger statusCode = operation.HTTPRequestOperation.response.statusCode;

        switch (statusCode) {
            case 0: // No internet connection
            {
            }
                break;
            case  401: // not authenticated
            {
            }
                break;
                
            default:
            {
            }
                break;
        }
    }
}
```

Links:  
[RestKit Framework](http://restkit.org)  
[Class Documentation for RKObjectRequestOperation](http://restkit.org/api/latest/Classes/RKObjectRequestOperation.html)

_by Albert Schulz_  
If you have any questions feel free to contact me:  
eMail: mail@halfco.de  
Twitter: [@albert_sn](https://twitter.com/albert_sn)  
Web: [halfco.de](http://halfco.de)  

