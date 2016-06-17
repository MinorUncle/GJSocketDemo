
//
//  ViewController.m
//  CFSocketClient
//
//  Created by tongguan on 16/6/16.
//  Copyright © 2016年 MinorUncle. All rights reserved.
//

#import "ViewController.h"
#import <CFNetwork/CFNetwork.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@interface ViewController ()
{
    BOOL start;
}
@end

@implementation ViewController
CFSocketRef _socket;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
int i;

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
int i=0;

void _socketCallBack(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info){
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
            
            sleep(1);
            NSString* str = [NSString stringWithFormat:@"i = %d",i++];
            CFDataRef sendData = CFDataCreate(NULL, (UInt8*)str.UTF8String, str.length);
            CFSocketError error;
            if (CFSocketIsValid(s)) {
                error = CFSocketSendData(s, NULL, sendData, 10);
            }
            CFDataRef remoteAddr =  CFSocketCopyPeerAddress(s);
            struct sockaddr_in* remote = (struct sockaddr_in*)CFDataGetBytePtr(remoteAddr);
            NSLog(@"senddata error:%ld,       %s",error,inet_ntoa(remote->sin_addr));
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
       _socket = [self _createSocketWithAddress:[self createAddressWithIP:inet_addr("192.168.0.57") port:1091 family:PF_INET] protocol:SOCK_STREAM isListen:NO];
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
