//
//  ViewController.m
//  MagicPad_Mac
//
//  Created by LAgagggggg on 2018/7/2.
//  Copyright © 2018 notme. All rights reserved.
//

#import "ViewController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <SystemConfiguration/SystemConfiguration.h>

#define WIDTH [NSScreen mainScreen].frame.size.width
#define HEIGHT [NSScreen mainScreen].frame.size.height

struct dataStruct{
    CGPoint trans;
    BOOL click;
};

@interface ViewController() <NSTableViewDataSource,NSTableViewDelegate,NSTextFieldDelegate,MCSessionDelegate,MCNearbyServiceBrowserDelegate,MCBrowserViewControllerDelegate,NSStreamDelegate>

@property (nonatomic,strong)MCPeerID * peerID;
@property (nonatomic,strong)MCSession * session;
@property (nonatomic,strong)MCAdvertiserAssistant * advertiser;
@property (nonatomic,strong)MCNearbyServiceBrowser * brower;
@property (nonatomic,strong)MCBrowserViewController * browserViewController;
@property (nonatomic,strong)NSMutableArray * sessionArray;
@property (nonatomic,strong)NSTableView * tableView;
@property (nonatomic,strong)NSMutableArray * dataArray;
@property (nonatomic,strong)NSTextField * chatField;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _dataArray = [NSMutableArray arrayWithCapacity:0];
    _sessionArray = [NSMutableArray arrayWithCapacity:0];
    [self createUI];
    [self createMC];
    
}

- (void)createUI{
    _tableView = [[NSTableView alloc]initWithFrame:CGRectMake(0, 20, WIDTH, HEIGHT - 400)];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [self.view addSubview:_tableView];
//    [_tableView registerClass:[NSTableViewCell class] forCellReuseIdentifier:@"ID"];
    
    _chatField = [[NSTextField alloc]initWithFrame:CGRectMake(0, HEIGHT - 360, WIDTH, 40)];
//    _chatField.borderStyle = UITextBorderStyleBezel;
//    _chatField.returnKeyType = UIReturnKeySend;
    _chatField.delegate = self;
    [self.view addSubview:_chatField];
}

#pragma mark TableViewDelegate
- (NSInteger)tableView:(NSTableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _dataArray.count;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView{
    return _dataArray.count;
}
//-(NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row{
//
//}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    NSView * rowV=[[NSTableRowView alloc]initWithFrame:CGRectMake(0, 0, WIDTH, 80)];
    NSTextField * textF=[NSTextField textFieldWithString:_dataArray[row]];
    [rowV addSubview:textF];
    return rowV;
}

/**
 *  连接设置
 */
- (void)createMC{
    NSString *name=NSFullUserName();
    //用户
    _peerID = [[MCPeerID alloc]initWithDisplayName:name];
    //为用户建立连接
    _session = [[MCSession alloc]initWithPeer:_peerID];
    //设置代理
    _session.delegate = self;
    //设置广播服务(发送方)
    _advertiser = [[MCAdvertiserAssistant alloc]initWithServiceType:@"type" discoveryInfo:nil session:_session];
    //开始广播
    [_advertiser start];
    //设置发现服务(接收方)
    _brower = [[MCNearbyServiceBrowser alloc]initWithPeer:_peerID serviceType:@"type"];
    //设置代理
    _brower.delegate = self;
    [_brower startBrowsingForPeers];
}

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info{
    NSLog(@"发现附近用户%@",peerID.displayName);
    if (_browserViewController == nil) {
        _browserViewController = [[MCBrowserViewController alloc]initWithServiceType:@"type" session:_session];
        _browserViewController.delegate = self;
        /**
         *  跳转发现界面
         */
        [self presentViewControllerAsModalWindow:self.browserViewController];
//        [self presentViewController:_browserViewController animated:YES completion:nil];
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID{
    
}

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController{
    [self dismissViewController:self.browserViewController];
//    [self dismissViewControllerAnimated:YES completion:nil];
    _browserViewController = nil;
    [_advertiser stop];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController{
    [self dismissViewController:self.browserViewController];
//    [self dismissViewControllerAnimated:YES completion:nil];
    _browserViewController = nil;
    [_advertiser stop];
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state{
    if (state == MCSessionStateConnected) {
        if (![_sessionArray containsObject:session]) {
            [_sessionArray addObject:session];
        }
        [self.brower stopBrowsingForPeers];
    }
    else if (state == MCSessionStateNotConnected){
        [self.brower startBrowsingForPeers];
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID{
    struct dataStruct dataS;
    [data getBytes:&dataS length:sizeof(dataS)];
    NSPoint curPos=[NSEvent mouseLocation];
    curPos.x+=dataS.trans.x;
    curPos.y=NSHeight([NSScreen screens][0].frame)-curPos.y;
    curPos.y+=dataS.trans.y;
    if (dataS.click) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CGEventRef downEvent = CGEventCreateMouseEvent(nil, kCGEventLeftMouseDown, curPos, kCGMouseButtonLeft);
            CGEventSetIntegerValueField(downEvent, kCGMouseEventClickState, 1);
            CGEventPost(kCGHIDEventTap, downEvent);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                CGEventRef upEvent = CGEventCreateMouseEvent(nil, kCGEventLeftMouseUp, curPos, kCGMouseButtonLeft);
                CGEventSetIntegerValueField(upEvent, kCGMouseEventClickState, 1);
                CGEventPost(kCGHIDEventTap, upEvent);

            });
        });
    }
    else{
        CGDisplayMoveCursorToPoint(0, curPos);
    }
}


//-(void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID{
//    NSLog(@"xxxx");
//    stream.delegate=self;
//    [stream scheduleInRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];
//    [stream open];
//}

//-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
//    if (eventCode==NSStreamEventHasBytesAvailable) {
//        CGPoint trans;
//        [(NSInputStream *)aStream read:&trans maxLength:sizeof(trans)];
//        NSPoint curPos=[NSEvent mouseLocation];
//        curPos.x+=trans.x;
//        curPos.y=NSHeight([NSScreen screens][0].frame)-curPos.y;
//        curPos.y+=trans.y;
//        CGDisplayMoveCursorToPoint(0, curPos);
//    }
//}

@end

