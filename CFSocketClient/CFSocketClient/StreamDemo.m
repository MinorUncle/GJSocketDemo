
//
//  ViewController.m
//  CFSocketClient
//
//  Created by tongguan on 16/6/16.
//  Copyright © 2016年 MinorUncle. All rights reserved.
//

#import "StreamDemo.h"
#import <CFNetwork/CFNetwork.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
//不能直接创建手动socket连接到服务器后再用该socket创建stream,stream会没有回调，把socket回调关闭也没有用，所有直接采用CFStreamCreatePairWithSocketToHost，但是貌似一直不走read回调
@interface StreamDemo ()
{
    BOOL start;
    CFSocketRef _socket;
   
}
@end

@implementation StreamDemo
static CFReadStreamRef _readStream;
static CFWriteStreamRef _writeStream;
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
static int i;
-(CFSocketRef)_createSocketWithAddress:(CFDataRef)dataRef protocol:(SInt32)protocol isListen:(bool)isListen {
    struct sockaddr_in* add = (struct sockaddr_in*)CFDataGetBytePtr(dataRef);
    CFOptionFlags flg = kCFSocketAcceptCallBack|kCFSocketConnectCallBack;
    if (!isListen) {
        flg = 0;
    }
//    __weak ViewController* week = self;
    CFSocketRef socket = CFSocketCreate(kCFAllocatorDefault, add->sin_family, protocol, IPPROTO_TCP,flg, _socketCallBack, NULL /*此处不能是self的引用，不知道为啥子*/);
    if (socket == NULL) {
        NSLog(@"CFSocketCreate error");
        return NULL;
    }
    CFSocketError err;
    if (isListen) {
        err =  CFSocketSetAddress(socket, dataRef);
        if (err != kCFSocketSuccess) {
            NSLog(@"CFSocketSetAddress error:%ld",err);
            return NULL;
        }else{
            NSLog(@"begin Listen onPort:%u",ntohs(add->sin_port));
        }
        int opt = 1;
        setsockopt(CFSocketGetNative(socket), SOL_SOCKET, SO_REUSEADDR, (void*)&opt, sizeof(opt));
    }else{
        err = CFSocketConnectToAddress(socket, dataRef, 10);
        if (err != kCFSocketSuccess) {
            NSLog(@"CFSocketConnectToAddress to Adress:%s port:%u error:%ld",inet_ntoa(add->sin_addr),ntohs(add->sin_port),err);
            return NULL;
        }else{
            NSLog(@"connent to Adress success:%s port:%u",inet_ntoa(add->sin_addr),ntohs(add->sin_port));
        }
    }
//    if (err != 0) {
//        CFRunLoopSourceRef soc = CFSocketCreateRunLoopSource(NULL, socket, 0);
//        CFRunLoopAddSource(CFRunLoopGetCurrent(), soc, kCFRunLoopCommonModes);
//    }
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
static void readStream(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo){
    
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
static void writeStream(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo){
    
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


static void _socketCallBack(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info){
    switch (type) {
        case kCFSocketConnectCallBack:
        {
            if (data == NULL) {
                NSLog(@"连接成功");
            }else{
                NSLog(@"连接失败,%s", (data == NULL)?"null": (char*)CFDataGetBytePtr(data));
            }
        }
            break;
        case kCFSocketReadCallBack:
        {
            NSLog(@"kCFSocketReadCallBack data:%s",(data == NULL)?"null": (char*)CFDataGetBytePtr(data));
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

        }
            break;
        case kCFSocketDataCallBack:
        {
            NSLog(@"kCFSocketDataCallBack data:%s", (data == NULL)?"null": (char*)CFDataGetBytePtr(data));
        }
            break;
        case kCFSocketAcceptCallBack:
        {
            NSLog(@"kCFSocketAcceptCallBack data:%s", (data == NULL)?"null": (char*)CFDataGetBytePtr(data));
        }
            break;
        case kCFSocketWriteCallBack:
        {
            NSLog(@"Connect Success Respone data:%s", (data == NULL)?"": (char*)CFDataGetBytePtr(data));
//            sendataToSocket(_writeStream);
        }
            break;
        default:
            break;
    }
}
static void sendataToSocket(CFWriteStreamRef _writeStream){
    NSString* dataS = [NSString stringWithFormat:@"%d",i++];
    CFSocketError error;

   CFIndex lengt = CFWriteStreamWrite(_writeStream, (UInt8*)dataS.UTF8String, dataS.length);
    if (lengt <= 0 ) {
        NSLog(@"发送失败");
    }
    CFDataRef remoteHandle = CFWriteStreamCopyProperty(_writeStream, kCFStreamPropertySocketNativeHandle);
    
    CFSocketNativeHandle* nativeHnadle = (CFSocketNativeHandle*)CFDataGetBytePtr(remoteHandle);
    struct sockaddr_in remote;
    socklen_t lenth = sizeof(remote);
    getpeername(*nativeHnadle, (struct sockaddr *)&remote, &lenth);

    NSLog(@"send:%s ToIp:%s error:%ld",dataS.UTF8String,inet_ntoa(remote.sin_addr),error);
}


-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    start = !start;
    if (start) {
        NSLog(@"开始连接");
        
       _socket = [self _createSocketWithAddress:[self createAddressWithIP:inet_addr("192.168.0.58") port:9000 family:PF_INET] protocol:SOCK_STREAM isListen:NO];
        if (1) {
//            CFHostRef host = CFHostCreateWithAddress(NULL,[self createAddressWithIP:inet_addr("192.168.0.58") port:9000 family:PF_INET]);
//            CFStreamCreatePairWithSocketToCFHost(NULL, host, 9000, &_readStream, &_writeStream);

            CFStringRef host = CFStringCreateWithCString(NULL, "192.168.0.58", kCFStringEncodingUTF8);
            CFStreamCreatePairWithSocketToHost(NULL, host, 9000, &_readStream, &_writeStream);
            
            if(_readStream && _writeStream){
                CFOptionFlags readStreamEvents = kCFStreamEventHasBytesAvailable;

                CFStreamClientContext streamCtxt = {0,NULL, NULL, NULL, NULL};
                if(!CFReadStreamSetClient(
                                          _readStream,
                                          readStreamEvents, //有可用数据则执行
                                          readStream,                      //设置读取时候的函数
                                          &streamCtxt))
                {exit(1);}
                CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
                
                CFOptionFlags writeStreamEvents = kCFStreamEventCanAcceptBytes |
                kCFStreamEventErrorOccurred  |
                kCFStreamEventEndEncountered |
                kCFStreamEventOpenCompleted;

                if(!CFWriteStreamSetClient(       //为流指定一个在运行循环中接受回调的客户端
                                           _writeStream,
                                           writeStreamEvents, //输出流准备完毕，可输出
                                           writeStream,                    //设置写入时候的函数
                                           &streamCtxt))
                {exit(1);}
                CFWriteStreamScheduleWithRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
                CFReadStreamSetProperty(_readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
                CFWriteStreamSetProperty(_writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            }else{
                NSLog(@"CFStreamCreatePairWithSocket  error");
            }
            
            Boolean result = CFReadStreamOpen(_readStream);
            if (!result) {
                NSLog(@"CFReadStreamOpen faile");
            }
            result = CFWriteStreamOpen(_writeStream);
            if (!result) {
                NSLog(@"CFWriteStreamOpen faile");
            }
        }
    }else{
        NSLog(@"断开连接");
        CFReadStreamUnscheduleFromRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFWriteStreamUnscheduleFromRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFReadStreamClose(_readStream);
        CFWriteStreamClose(_writeStream);
        if (CFSocketIsValid(_socket)) {
            CFSocketInvalidate(_socket);
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
