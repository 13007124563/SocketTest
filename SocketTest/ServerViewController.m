//
//  ServerViewController.m
//  SocketTest
//
//  Created by fang on 2020/10/5.
//

#import "ServerViewController.h"
#import <Masonry/Masonry.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

//htons : 将一个无符号短整型的主机数值转换为网络字节顺序，不同cpu 是不同的顺序 (big-endian大尾顺序 , little-endian小尾顺序)
#define SocketPort htons(8040)
//inet_addr是一个计算机函数，功能是将一个点分十进制的IP转换成一个长整数型数
#define SocketIP inet_addr("127.0.0.1")

#define maxConnectCount 5

@interface ServerViewController ()

@property (nonatomic, assign) int serverID;

@property (nonatomic, assign) int client_socketID;

// MARK: - UI
@property (nonatomic, strong) UIButton *startServerBtn;

@property (nonatomic, strong) UITextField *sendTextField;

@property (nonatomic, strong) UIButton *sendBtn;

@property (nonatomic, strong) UIButton *closeServerBtn;

@end

@implementation ServerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    
    [self.view addSubview:self.startServerBtn];
    [self.startServerBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(100);
        make.centerX.equalTo(self.view);
        make.width.equalTo(self.view).multipliedBy(0.5);
        make.height.equalTo(@50);
    }];
    
    [self.view addSubview:self.sendTextField];
    [self.view addSubview:self.sendBtn];
    
    [self.sendTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.height.equalTo(self.startServerBtn);
        make.top.equalTo(self.startServerBtn.mas_bottom).offset(50);
    }];
    
    [self.sendBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.sendTextField.mas_right);
        make.width.equalTo(@50);
        make.right.equalTo(self.startServerBtn);
        make.centerY.height.equalTo(self.sendTextField);
    }];
    
    [self.view addSubview:self.closeServerBtn];
    [self.closeServerBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.width.height.equalTo(self.startServerBtn);
        make.top.equalTo(self.sendTextField.mas_bottom).offset(50);
    }];
}

- (void)acceptSocket {
    struct sockaddr_in client_socketAddress;
    socklen_t address_len;
    
    //accept函数
    int client_socketID = accept(self.serverID, (struct sockaddr *restrict)&client_socketAddress, &address_len);
    self.client_socketID = client_socketID;
    
    if (client_socketID == -1) {
        NSLog(@"接收%@客户端错误",@(address_len));
        return;
    } else {
        NSString *acceptInfo = [NSString stringWithFormat:@"客户端 in, socket:%@",@(client_socketID)];
        
        NSLog(@"%@",acceptInfo);
        
        [self receiveMsgWithClietnSocket:client_socketID];
    }
}

// 5. 接收消息
- (void)receiveMsgWithClietnSocket:(int)clientSocketID {
    while (1) {
        char buf[1024] = {0};
        long bufLen = recv(clientSocketID, buf, 1024, 0);
        
        if (bufLen > 0) {
            NSData *recvData = [[NSData alloc] initWithBytes:buf length:bufLen];
            NSString *recvStr = [[NSString alloc] initWithData:recvData encoding:NSUTF8StringEncoding];
            
            NSLog(@"收到客户端消息:%@",recvStr);
        } else if (bufLen == -1) {
            NSLog(@"客户端消息读取失败");
            break;
        } else if (bufLen == 0) {
            NSLog(@"客户端已关闭");
            close(clientSocketID);
            break;
        }
    }
}

// 6. 发送消息
- (void)sendBtnClick {
    //注意发送时的套接字是连接套接字，而不是服务器的套接字
    const char* msg = self.sendTextField.text.UTF8String;
    ssize_t sendLen = send(self.client_socketID, msg, strlen(msg), 0);
    NSLog(@"socket发送了%@字节",@(sendLen));
}

- (void)closeServerBtnClick {
    if (close(self.serverID) == -1) {
        NSLog(@"socket关闭失败");
    } else {
        NSLog(@"socket关闭成功");
    }
}

// MARK: - Private
- (void)startServerBtnClick {
    // 1. 创建socket
    self.serverID = socket(AF_INET, SOCK_STREAM, 0);
    
    if (self.serverID == -1) {
        NSLog(@"创建socket失败");
        return;
    } else {
        NSLog(@"创建socket成功");
    }
    
    // 2. 绑定socket
    struct sockaddr_in socketAddr;
    socketAddr.sin_family = AF_INET;
    socketAddr.sin_port = SocketPort;
    
    struct in_addr socketIn_addr;
    socketIn_addr.s_addr = SocketIP;
    
    socketAddr.sin_addr = socketIn_addr;
    
    if (bind(self.serverID, (const struct sockaddr *)&socketAddr, sizeof(socketAddr)) == -1) {
        NSLog(@"绑定Socket失败");
        return;
    } else {
        NSLog(@"绑定socket成功");
    }
    
    // 3. 添加socket监听,让服务器监听客户端的请求
    if (listen(self.serverID, maxConnectCount) == -1) {
        NSLog(@"监听失败");
        return;
    } else {
        NSLog(@"监听成功");
    }
    
    // 4. accept , 当客户端发送请求时，程序为serverSocket创建一个新套接字 ConnectionSocket，用于clientSocket和serverSocket之间创建一个TCP连接
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self acceptSocket];
    });
}

// MARK: - Getter && Setter

- (UIButton *)startServerBtn {
    if (!_startServerBtn) {
        _startServerBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _startServerBtn.backgroundColor = UIColor.orangeColor;
        [_startServerBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [_startServerBtn addTarget:self action:@selector(startServerBtnClick) forControlEvents:UIControlEventTouchUpInside];
        [_startServerBtn setTitle:@"连接Socket" forState:UIControlStateNormal];
    }
    
    return _startServerBtn;
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

- (UIButton *)closeServerBtn {
    if (!_closeServerBtn) {
        _closeServerBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _closeServerBtn.backgroundColor = UIColor.orangeColor;
        [_closeServerBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [_closeServerBtn addTarget:self action:@selector(closeServerBtnClick) forControlEvents:UIControlEventTouchUpInside];
        [_closeServerBtn setTitle:@"关闭Server" forState:UIControlStateNormal];
    }
    
    return _closeServerBtn;
}
@end
