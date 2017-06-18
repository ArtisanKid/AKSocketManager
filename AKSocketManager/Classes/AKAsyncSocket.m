//
//  AKAsyncSocket.m
//  Pods
//
//  Created by 李翔宇 on 2017/1/1.
//
//

#import "AKAsyncSocket.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "AKSocketManagerMacro.h"
#import "AKSocketWrite.h"

static NSTimeInterval AKAsyncSocketTimeoutNever = -1;

@interface AKAsyncSocket () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) uint16_t port;

@property (nonatomic, assign, getter=isStartedReadData) BOOL startedReadData;
@property (nonatomic, assign) NSUInteger readDataTimes;//读数据次数

@property (nonatomic, assign) NSUInteger writeDataTimes;//写数据次数
@property (atomic, strong) NSMutableArray<AKSocketWrite *> *writesM;
@property (atomic, strong) NSMapTable<NSString *, AKSocketWrite *> *writeMapTable;


@property (nonatomic, assign, getter=isForceDisconnect) BOOL forceDisconnect;//是否强制断开
@property (nonatomic, assign) NSUInteger reconnectTimes;//重连次数

@end

@implementation AKAsyncSocket

+ (instancetype)socket {
    static AKAsyncSocket *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}

- (void)dealloc {
    _socket.delegate = nil;
    [_socket disconnect];
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        _writesM = [NSMutableArray array];
        _writeMapTable = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}

- (BOOL)connectToHost:(NSString *)host onPort:(uint16_t)port {
    /**
     如果已经有host何port了，说明已经连接过
     如果再次传入的参数和已有参数相同，那么直接返回socket状态
     如果不同，那么直接返回NO，表示连接错误
     */
    if(self.host.length && self.port) {
        if([self.host isEqualToString:host] && self.port == port) {
            AKSocketManagerLog(@"已创建socket");
            return self.socket.isConnected;
        } else {
            AKSocketManagerLog(@"请先断开socket");
            return NO;
        }
    }
    
    self.host = host;
    self.port = port;
    return [self connect];
}

- (void)disconnect {
    if(self.socket.isDisconnected) {
        return;
    }
    
    if([self.delegate respondsToSelector:@selector(socket:didChangeState:)]) {
        [self.delegate socket:self didChangeState:AKAsyncSocketStateDisconnecting];
    }
    
    self.forceDisconnect = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    self.startedReadData = NO;
    self.readDataTimes = 0;
    self.writeDataTimes = 0;
    [self.writesM removeAllObjects];
    self.reconnectTimes = 0;
    
    self.host = nil;
    self.port = 0;
    
    self.socket.delegate = nil;
    [self.socket disconnect];
}

- (void)startReadData {
    if(self.isStartedReadData) {
        return;
    }
    
    self.startedReadData = YES;
    
    if(!self.socket.isConnected) {
        return;
    }
    
    [self.socket readDataWithTimeout:AKAsyncSocketTimeoutNever tag:self.readDataTimes++];
}

- (NSString *)writeData:(NSData *)data expiredTime:(NSTimeInterval)expiredTime complete:(AKAsyncSocketWriteComplete)complete {
    if(!data.length) {
        !complete ? : complete(NO);
        return nil;
    }
    
    AKSocketWrite *write = [[AKSocketWrite alloc] init];
    write.writeID = @(data.hash).description;
    write.data = data;
    write.expiredTime = expiredTime;
    write.createdTime = [NSDate date].timeIntervalSince1970;
    write.complete = complete;
    [self.writesM addObject:write];
    [self.writeMapTable setObject:write forKey:write.writeID];

    if(!self.socket.isConnected) {
        return write.writeID;
    }
    
    if(self.writesM.firstObject != write) {
        return write.writeID;
    }
    
    AKSocketManagerLog(@"writeID:%@", write.writeID);
    
    [self writeNext];
    return write.writeID;
}

- (BOOL)cancelWrite:(NSString *)writeID {
    if(!writeID.length) {
        return NO;
    }
    
    AKSocketWrite *write = [self.writeMapTable objectForKey:writeID];
    if(!write) {
        return NO;
    }
    
    if(write.isWriting) {
        return NO;
    }
    
    AKSocketManagerLog(@"取消写入 writeID:%@", writeID);
    
    [self.writesM removeObject:write];
    return YES;
}

#pragma mark - Private
- (BOOL)connect {
    AKSocketManagerLog(@"正在连接socket...");
    
    if([self.delegate respondsToSelector:@selector(socket:didChangeState:)]) {
        [self.delegate socket:self didChangeState:AKAsyncSocketStateConnecting];
    }
    
    NSError *error = nil;
    BOOL isConnected = [self.socket connectToHost:self.host onPort:self.port error:&error];
    if(!isConnected) {
        AKSocketManagerLog(@"error:%@", error);
    }
    return isConnected;
}

- (void)writeNext {
    if(!self.writesM.count) {
        AKSocketManagerLog(@"数据写入完成");
        return;
    }
    
    AKSocketWrite *write = self.writesM.firstObject;
    if(write.isWriting) {
        AKSocketManagerLog(@"数据正在写入socket...");
        return;
    }
    
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    if(write.expiredTime <= now) {
        AKSocketManagerLog(@"数据过期");
        [self completeWrite:write success:NO];
        return;
    }
    
    AKSocketManagerLog(@"数据开始写入socket...");
    
    write.writing = YES;
    write.createdTime = now;
    
    NSTimeInterval timeout = write.expiredTime - now;
    [self.socket writeData:write.data withTimeout:timeout tag:[write.writeID integerValue]];
}

- (void)completeWrite:(AKSocketWrite *)write success:(BOOL)success {
    if(!write) {
        AKSocketManagerLog(@"未找到指定的write对象");

        [self writeNext];
        return;
    }
    
    [self.writesM removeObject:write];
    
    AKAsyncSocketWriteComplete complete = write.complete;
    !complete ? : complete(success);
    
    [self writeNext];
}

#pragma mark - GCDAsyncSocketDelegate

/**
 * Called when a socket connects and is ready for reading and writing.
 * The host parameter will be an IP address, not a DNS name.
 **/
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    AKSocketManagerLog(@"host:%@ port:%@", host, @(port));
    
    if([self.delegate respondsToSelector:@selector(socket:didChangeState:)]) {
        [self.delegate socket:self didChangeState:AKAsyncSocketStateConnected];
    }
    
    self.reconnectTimes = 0;
    self.forceDisconnect = NO;
    
    if(self.isStartedReadData) {
        [sock readDataWithTimeout:AKAsyncSocketTimeoutNever tag:self.readDataTimes++];
    }
    
    [self writeNext];
}

/**
 * Called when a socket disconnects with or without error.
 *
 * If you call the disconnect method, and the socket wasn't already disconnected,
 * then an invocation of this delegate method will be enqueued on the delegateQueue
 * before the disconnect method returns.
 *
 * Note: If the GCDAsyncSocket instance is deallocated while it is still connected,
 * and the delegate is not also deallocated, then this method will be invoked,
 * but the sock parameter will be nil. (It must necessarily be nil since it is no longer available.)
 * This is a generally rare, but is possible if one writes code like this:
 *
 * asyncSocket = nil; // I'm implicitly disconnecting the socket
 *
 * In this case it may preferrable to nil the delegate beforehand, like this:
 *
 * asyncSocket.delegate = nil; // Don't invoke my delegate method
 * asyncSocket = nil; // I'm implicitly disconnecting the socket
 *
 * Of course, this depends on how your state machine is configured.
 **/
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    AKSocketManagerLog(@"error:%@", err);
    
    if([self.delegate respondsToSelector:@selector(socket:didChangeState:)]) {
        [self.delegate socket:self didChangeState:AKAsyncSocketStateDisconnected];
    }
    
    if(self.isForceDisconnect) {
        return;
    }
    
    if(self.reconnectTimes <= 8) {
        self.reconnectTimes++;
    }
    if([self.delegate respondsToSelector:@selector(socket:didChangeState:)]) {
        [self.delegate socket:self didChangeState:AKAsyncSocketStateWaitingReconnect];
    }
    [self performSelector:@selector(connect) withObject:nil afterDelay:pow(2, self.reconnectTimes)];
}

/**
 * Called when a socket has completed reading the requested data into memory.
 * Not called if there is an error.
 **/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    AKSocketManagerLog(@"data:%@\n数据长度%@ tag:%@", data, @(data.length), @(tag));
    
    [self.delegate socket:self didReadData:data];
    [sock readDataWithTimeout:AKAsyncSocketTimeoutNever tag:self.readDataTimes++];
}

/**
 * Called when a socket has completed writing the requested data. Not called if there is an error.
 **/
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    AKSocketManagerLog(@"tag:%@", @(tag));
    
    //NSPredicate(谓词)如果匹配类型不一致，会导致匹配失败
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"writeID = %@", @(tag).description];
    AKSocketWrite *write = [self.writesM filteredArrayUsingPredicate:predicate].lastObject;
    [self completeWrite:write success:YES];
}

@end
