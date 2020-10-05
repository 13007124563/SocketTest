//
//  ViewController.m
//  SocketTest
//
//  Created by fang on 2020/10/5.
//

#import "ViewController.h"
#import <Masonry/Masonry.h>

#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

//htons : 将一个无符号短整型的主机数值转换为网络字节顺序，不同cpu 是不同的顺序 (big-endian大尾顺序 , little-endian小尾顺序)
#define SocketPort htons(8040)
//inet_addr是一个计算机函数，功能是将一个点分十进制的IP转换成一个长整数型数
#define SocketIP inet_addr("127.0.0.1")

@interface ViewController ()

@property (nonatomic, strong) UIButton *connectBtn;

@property (nonatomic, strong) UITextField *sendTextField;

@property (nonatomic, strong) UIButton *sendBtn;

@property (nonatomic, strong) UITextView *logTextView;

// MARK: - Socket
//用于接收socket创建成功后的返回值
@property (nonatomic, assign) int clientID;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.view addSubview:self.connectBtn];
    [self.connectBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(100);
        make.centerX.equalTo(self.view);
        make.width.equalTo(self.view).multipliedBy(0.5);
        make.height.equalTo(@50);
    }];
    
    [self.view addSubview:self.sendTextField];
    [self.view addSubview:self.sendBtn];
    
    [self.sendTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.height.equalTo(self.connectBtn);
        make.top.equalTo(self.connectBtn.mas_bottom).offset(50);
    }];
    
    [self.sendBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.sendTextField.mas_right);
        make.width.equalTo(@50);
        make.right.equalTo(self.connectBtn);
        make.centerY.height.equalTo(self.sendTextField);
    }];
    
    [self.view addSubview:self.logTextView];
    [self.logTextView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.sendBtn.mas_bottom).offset(50);
        make.left.equalTo(self.view).offset(50);
        make.right.equalTo(self.view).offset(-50);
        make.height.equalTo(@300);
    }];
    
}

// MARK: - Private
- (void)connectBtnClick {
    /*
     函数原型：
     int socket(int domain, int type, int protocol);
     
     domain：协议域，又称协议族（family）。常用的协议族有AF_INET(ipv4)、AF_INET6(ipv6)、AF_LOCAL（或称AF_UNIX，Unix域Socket）、AF_ROUTE等。协议族决定了socket的地址类型，在通信中必须采用对应的地址，如AF_INET决定了要用ipv4地址（32位的）与端口号（16位的）的组合、AF_UNIX决定了要用一个绝对路径名作为地址。

     type：指定Socket类型。常用的socket类型有SOCK_STREAM、SOCK_DGRAM、SOCK_RAW、SOCK_PACKET、SOCK_SEQPACKET等。流式Socket（SOCK_STREAM）是一种面向连接的Socket，针对于面向连接的TCP服务应用。数据报式Socket（SOCK_DGRAM）是一种无连接的Socket，对应于无连接的UDP服务应用。

     protocol：指定协议。常用协议有IPPROTO_TCP、IPPROTO_UDP、IPPROTO_STCP、IPPROTO_TIPC等，分别对应TCP传输协议、UDP传输协议、STCP传输协议、TIPC传输协议。
     注意：type和protocol不可以随意组合，如SOCK_STREAM不可以跟IPPROTO_UDP组合。当第三个参数为0时，会自动选择第二个参数类型对应的默认协议。

     返回值：如果调用成功就返回新创建的套接字的描述符，如果失败就返回INVALID_SOCKET（Linux下失败返回-1）。套接字描述符是一个整数类型的值。
     */
    // 1. 创建socket
    _clientID = socket(AF_INET, SOCK_STREAM, 0);
    
    if (_clientID == -1) {
        [self logMessage:@"创建socket失败"];
        return;
    } else {
        [self logMessage:@"创建socket成功"];
    }
    
    /*
     __uint8_t    sin_len;          假如没有这个成员，其所占的一个字节被并入到sin_family成员中
     sa_family_t    sin_family;     一般来说AF_INET（地址族）PF_INET（协议族）
     in_port_t    sin_port;         // 端口
     struct    in_addr sin_addr;    // ip
     char        sin_zero[8];       没有实际意义,只是为了　跟SOCKADDR结构在内存中对齐
     */

    struct sockaddr_in socketAddr;
    socketAddr.sin_family = AF_INET;
    socketAddr.sin_port = SocketPort;
    
    struct in_addr socketIn_addr;
    socketIn_addr.s_addr = SocketIP;
    
    socketAddr.sin_addr = socketIn_addr;
    
    /*
     函数原型：
     int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
     
     参数说明：
     sockfd：标识一个已连接套接口的描述字，就是我们刚刚创建的那个_clinenId。
     addr：指针，指向目的套接字的地址。
     addrlen：接收返回地址的缓冲区长度。
     返回值：成功则返回0，失败返回非0，错误码GetLastError()。
     */
    // 2. 连接socket
    int result = connect(_clientID, (const struct sockaddr *)&socketAddr, sizeof(socketAddr));
    if (result != 0) {
        [self logMessage:@"连接socket失败"];
        return;
    } else {
        [self logMessage:@"连接socket成功"];
    }
    
    // 调用开始接收信息的方法
    // while 如果主线程会造成堵塞
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self recvMessage];
    });
}

- (void)sendBtnClick {
    // 3. 发送消息
    if (self.sendTextField.text.length == 0) {
        return;
    }
    
    const char *msg = [self.sendTextField.text stringByAppendingString:@"\n"].UTF8String;
    
    ssize_t sendLen = send(self.clientID, msg, strlen(msg), 0);
    [self logMessage:[NSString stringWithFormat:@"发送了%@字节",@(sendLen)]];
    [self logMessage:[NSString stringWithFormat:@"发送到的字符串:%@",[NSString stringWithUTF8String:msg]]];
}

- (void)recvMessage {
    // 4. 接收数据
    while (1) {
        uint8_t buffer[1024];
        ssize_t recvLen = recv(self.clientID, buffer, sizeof(buffer), 0);
        [self logMessage:[NSString stringWithFormat:@"接收了%@字节",@(recvLen)]];
        
        if (recvLen == 0) {
            continue;
        }
        
        //buffer -> data -> string
        NSData *data = [NSData dataWithBytes:buffer length:recvLen];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        [self logMessage:[NSString stringWithFormat:@"接收到的字符串:%@",str]];
    }
}

- (void)logMessage:(NSString *)str {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logTextView.text = [self.logTextView.text stringByAppendingFormat:@"%@\n",str];
    });
}

// MARK: - Getter && Setter

- (UIButton *)connectBtn {
    if (!_connectBtn) {
        _connectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _connectBtn.backgroundColor = UIColor.orangeColor;
        [_connectBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [_connectBtn addTarget:self action:@selector(connectBtnClick) forControlEvents:UIControlEventTouchUpInside];
        [_connectBtn setTitle:@"连接Socket" forState:UIControlStateNormal];
    }
    
    return _connectBtn;
}

- (UITextField *)sendTextField {
    if (!_sendTextField) {
        _sendTextField = [[UITextField alloc] init];
        _sendTextField.placeholder = @"发送消息";
        _sendTextField.backgroundColor = UIColor.lightGrayColor;
        _sendTextField.borderStyle = UITextBorderStyleRoundedRect;
    }
    
    return _sendTextField;
}

- (UIButton *)sendBtn {
    if (!_sendBtn) {
        _sendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_sendBtn addTarget:self action:@selector(sendBtnClick) forControlEvents:UIControlEventTouchUpInside];
        [_sendBtn setTitle:@"发送" forState:UIControlStateNormal];
    }
    
    return _sendBtn;
}

- (UITextView *)logTextView {
    if (!_logTextView) {
        _logTextView = [[UITextView alloc] init];
        _logTextView.backgroundColor = UIColor.grayColor;
    }
    
    return _logTextView;
}

@end
