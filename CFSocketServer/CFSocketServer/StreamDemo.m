//
//  ViewController.m
//  CFSocketServer
//
//  Created by tongguan on 16/6/16.
//  Copyright © 2016年 MinorUncle. All rights reserved.
//

#import "StreamDemo.h"
#import <CFNetwork/CFNetwork.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
@interface StreamDemo ()
{
    CFSocketRef _socket;
    
}
@end

@implementation StreamDemo

- (void)viewDidLoad {
    
    [super viewDidLoad];
    NSLog(@"localIP:%@",[self getIPAddress]);
    [self _createSocketWithAddress:[self createAddressWithIP:INADDR_ANY port:9000 family:PF_INET] protocol:SOCK_STREAM isListen:YES];
    //    [self _createSocketWithIP:INADDR_ANY Port:1090 protocol:SOCK_STREAM family:PF_INET isListen:YES];
    // Do any additional setup after loading the view, typically from a nib.
}
- (NSString *)getIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if( temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}
static int i;
static void sendataToSocket(CFSocketRef socket){
    NSString* dataS = [NSString stringWithFormat:@"%d",i++];
    CFDataRef data = CFDataCreate(NULL,(UInt8*)dataS.UTF8String , dataS.length);
    CFSocketError error;
    if (CFSocketIsValid(socket)) {
        error = CFSocketSendData(socket, NULL, data, 10);
    }
    CFDataRef remoteAddr =  CFSocketCopyPeerAddress(socket);
    struct sockaddr_in* remote = (struct sockaddr_in*)CFDataGetBytePtr(remoteAddr);
    NSLog(@"send:%s ToIp:%s error:%ld",dataS.UTF8String,inet_ntoa(remote->sin_addr),error);
}

-(CFSocketRef)_createSocketWithAddress:(CFDataRef)dataRef protocol:(SInt32)protocol isListen:(bool)isListen {
    struct sockaddr_in* add = (struct sockaddr_in*)CFDataGetBytePtr(dataRef);
    CFOptionFlags flg = kCFSocketAcceptCallBack|kCFSocketConnectCallBack;
    if (!isListen) {
        flg = 15-2;
    }
    CFSocketRef socket = CFSocketCreate(kCFAllocatorDefault, add->sin_family, protocol, 0,flg, _socketCallBack, (__bridge void *)(self));
    if (socket == NULL) {
        NSLog(@"CFSocketCreate error");
        return NULL;
    }
    if (isListen) {
        CFSocketError err =  CFSocketSetAddress(socket, dataRef);
        if (err != kCFSocketSuccess) {
            NSLog(@"CFSocketSetAddress error:%ld",err);
            return NULL;
        }else{
            NSLog(@"begin Listen onPort:%u",ntohs(add->sin_port));
        }
        int opt = 1;
        setsockopt(CFSocketGetNative(socket), SOL_SOCKET, SO_REUSEADDR, (void*)&opt, sizeof(opt));
    }else{
        CFSocketError err = CFSocketConnectToAddress(socket, dataRef, 10);
        if (err != kCFSocketSuccess) {
            NSLog(@"CFSocketConnectToAddress to Adress:%s port:%u error:%ld",inet_ntoa(add->sin_addr),ntohs(add->sin_port),err);
            return NULL;
        }else{
            NSLog(@"connent to Adress:%s port:%u",inet_ntoa(add->sin_addr),ntohs(add->sin_port));
        }
    }
    CFRunLoopSourceRef soc = CFSocketCreateRunLoopSource(NULL, socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), soc, kCFRunLoopCommonModes);
    return socket;
}

-(CFDataRef)createAddressWithIP:(unsigned int)IP port:(int)port family:(unsigned char)family{
    struct sockaddr_in add;
    memset(&add, 0, sizeof(add));
    add.sin_family = family;
    add.sin_len = sizeof(add);
    add.sin_port = htons(port);
    add.sin_addr.s_addr = IP;//INADDR_ANY
    CFDataRef data = CFDataCreate(NULL, (UInt8*)&add, sizeof(add));
    return data;
}
static void _socketCallBack(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info){
    switch (type) {
        case kCFSocketConnectCallBack:
        {
            NSLog(@"kCFSocketConnectCallBack data:%s", (data == NULL)?"null": (char*)CFDataGetBytePtr(data));
        }
            break;
        case kCFSocketReadCallBack:
        {
            NSLog(@"kCFSocketReadCallBack data:%s", (data == NULL)?"null": (char*)CFDataGetBytePtr(data));
            char buffer[200];
            long result = recv(CFSocketGetNative(s), buffer, 200, 0);
            if (result < 0) {
                NSLog(@"recv error:%ld",result);
                CFSocketInvalidate(s);
                break;
            }else {
                NSLog(@"read:%s",buffer);
            }
            if (result == 0) {
                NSLog(@"remote close ");
                CFSocketInvalidate(s);
                break;
            }
            sleep(1);
        }
            break;
        case kCFSocketDataCallBack:
        {
            NSLog(@"kCFSocketDataCallBack data:%s",(data == NULL)?"null": (char*)CFDataGetBytePtr(data));
        }
            break;
        case kCFSocketAcceptCallBack:
        {
            NSLog(@"kCFSocketAcceptCallBack");
            CFSocketNativeHandle* handle = (CFSocketNativeHandle*)data;
//            CFSocketRef sendSocket = CFSocketCreateWithNative(NULL, *handle, 15-2, _socketCallBack, NULL);
            createStreamPairWithSocket(*handle);
        }
            break;
        case kCFSocketWriteCallBack:
        {
            NSLog(@"kCFSocketWriteCallBack data:%s",(data == NULL)?"null": (char*)CFDataGetBytePtr(data));
            
        }
            break;
            
        default:
            break;
    }
}
static void _readStream(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo){
    
    switch (type) {
        case kCFStreamEventOpenCompleted:
        {
            NSLog(@"kCFStreamEventOpenCompleted");
        }
            break;
        case kCFStreamEventErrorOccurred:
        {
            NSLog(@"kCFStreamEventOpenCompleted");
        }
            break;
        case kCFStreamEventEndEncountered:
        {
            NSLog(@"kCFStreamEventEndEncountered");
        }
            break;
            
        case kCFStreamEventHasBytesAvailable:
        {
            UInt8 buffer[200];
            NSLog(@"begin read type:%lu",type);
            CFIndex result = CFReadStreamRead(stream, buffer, 200);
            if (result <= 0) {
                NSLog(@"recv error:%ld",result);
            }else {
                NSLog(@"read:%s",buffer);
            }
            if (result == 0) {
                NSLog(@"remote close ");
            }
        }
            break;
            
            
        default:
            break;
    }
   }
static void _writeStream(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo){
    
    switch (type) {
        case kCFStreamEventOpenCompleted:
        {
            NSLog(@"kCFStreamEventOpenCompleted");
        }
            break;
        case kCFStreamEventErrorOccurred:
        {
            NSLog(@"kCFStreamEventOpenCompleted");
        }
            break;
        case kCFStreamEventEndEncountered:
        {
            NSLog(@"kCFStreamEventEndEncountered");
        }
            break;
            
        case kCFStreamEventCanAcceptBytes:
        {
            sleep(1);
            NSLog(@"begin write type:%lu",type);
            NSString* str = [NSString stringWithFormat:@"i = %d",i++];
            CFIndex result = CFWriteStreamWrite(stream, (UInt8*)str.UTF8String, str.length);
            if (result < 0) {
                NSLog(@"CFWriteStreamWrite error:%ld",result);
            }else {
                NSLog(@"send:%s",str.UTF8String);
            }
        }
            break;
        default:
            break;
    }
   }
static void createStreamPairWithSocket(CFSocketNativeHandle socket){
    CFStreamClientContext streamCtxt = {0,NULL, NULL, NULL, NULL};
    
    CFReadStreamRef readStream ;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocket(NULL, socket, &readStream, &writeStream);
    
    if (readStream!=NULL && writeStream!= NULL) {
        CFOptionFlags writeStreamEvents = kCFStreamEventCanAcceptBytes;
        if(!CFWriteStreamSetClient(writeStream, writeStreamEvents, _writeStream, &streamCtxt)){
            NSLog(@"CFWriteStreamSetClient failure");
        };
        CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        
        CFOptionFlags readStreamEvents = kCFStreamEventHasBytesAvailable |
        kCFStreamEventErrorOccurred     |
        kCFStreamEventEndEncountered    |
        kCFStreamEventOpenCompleted;
        if(!CFReadStreamSetClient(readStream, readStreamEvents, _readStream , &streamCtxt)){
            NSLog(@"CFReadStreamSetClient failure");

        };
        CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    }else{
        NSLog(@"CFStreamCreatePairWithSocket error");
    }
    
    bool result = CFReadStreamOpen(readStream);
    result *= CFWriteStreamOpen(writeStream);
    if (!result) {
        NSLog(@"stream open ERROR");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
