
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
        flg = 15-2;
    }
//    __weak ViewController* week = self;
    CFSocketRef socket = CFSocketCreate(kCFAllocatorDefault, add->sin_family, protocol, IPPROTO_TCP,flg, _socketCallBack, NULL /*此处不能是self的引用，不知道为啥子*/);
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
static void readStream(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo){
    UInt8 buffer[200];
    NSLog(@"begin read type:%lu",type);
    CFIndex result = CFReadStreamRead(stream, buffer, 200);
    if (result < 0) {
        NSLog(@"recv error:%ld",result);
    }else {
        NSLog(@"read:%s",buffer);
    }
    if (result == 0) {
        NSLog(@"remote close ");
    }
}
static void writeStream(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo){
    NSLog(@"begin write type:%lu",type);
    NSString* str = [NSString stringWithFormat:@"i = %d",i++];
    CFIndex result = CFWriteStreamWrite(stream, (UInt8*)str.UTF8String, str.length);
    if (result < 0) {
        NSLog(@"CFWriteStreamWrite error:%ld",result);
    }else {
        NSLog(@"send:%s",str.UTF8String);
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
        }
            break;
        default:
            break;
    }
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    start = !start;
    if (start) {
        NSLog(@"开始连接");
       _socket = [self _createSocketWithAddress:[self createAddressWithIP:inet_addr("192.168.0.51") port:1091 family:PF_INET] protocol:SOCK_STREAM isListen:NO];
        if (_socket != NULL) {
            CFStreamCreatePairWithSocket(NULL, CFSocketGetNative(_socket),&_readStream , &_writeStream);
            Boolean result = CFReadStreamOpen(_readStream);
            if (!result) {
                NSLog(@"CFReadStreamOpen faile");
            }
            result = CFWriteStreamOpen(_writeStream);
            if (!result) {
                NSLog(@"CFWriteStreamOpen faile");
            }
            if(_readStream && _writeStream){
                CFStreamClientContext streamCtxt = {0,NULL, NULL, NULL, NULL};
                if(!CFReadStreamSetClient(
                                          _readStream,
                                          31, //有可用数据则执行
                                          readStream,                      //设置读取时候的函数
                                          &streamCtxt))
                {exit(1);}
                
                CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
                if(!CFWriteStreamSetClient(       //为流指定一个在运行循环中接受回调的客户端
                                           _writeStream,
                                           31, //输出流准备完毕，可输出
                                           writeStream,                    //设置写入时候的函数
                                           &streamCtxt))
                {exit(1);}
                CFWriteStreamScheduleWithRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

            }else{
                NSLog(@"CFStreamCreatePairWithSocket  error");
            }
        }
    }else{
        NSLog(@"断开连接");
        CFSocketInvalidate(_socket);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
