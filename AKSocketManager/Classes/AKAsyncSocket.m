//
//  AKAsyncSocket.m
//  Pods
//
//  Created by 李翔宇 on 2017/1/1.
//
//

#import "AKAsyncSocket.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "AKSocketWrite.h"

static NSTimeInterval AKAsyncSocketTimeoutNever = - CGFLOAT_MIN;

@interface AKAsyncSocket () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) uint16_t port;

@property (nonatomic, assign, getter=isReadData) BOOL readData;
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
        //SJBLOGL(SJBMessageLogPrefix, @"实例化SJBMessageManager单例");
    });
    return sharedInstance;
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
    if(self.host.length && self.port) {
        if([self.host isEqualToString:host] && self.port == port) {
            return self.socket.isConnected;
        } else {
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
    
    self.forceDisconnect = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    self.readData = NO;
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
    if(self.isReadData) {
        return;
    }
    
    self.readData = YES;
    
    if(!self.socket.isConnected) {
        return;
    }
    
    [self.socket readDataWithTimeout:AKAsyncSocketTimeoutNever tag:self.readDataTimes++];
}

- (NSString *)writeData:(NSData *)data expiredTime:(NSTimeInterval)time complete:(AKAsyncSocketWriteComplete)complete {
    if(!data.length) {
        return nil;
    }
    
    AKSocketWrite *write = [[AKSocketWrite alloc] init];
    write.writeID = @(data.hash).description;
    write.data = data;
    write.expiredTime = time;
    write.createdTime = [NSDate date].timeIntervalSince1970;
    write.complete = complete;
    [self.writesM addObject:write];
    [self.writeMapTable setObject:write forKey:write.writeID];
    
    __weak typeof(self) weak_self = self;
    [write monitorTimeout:^(AKSocketWrite *write) {
        __strong typeof(weak_self) strong_self = weak_self;
        if(!strong_self) {
            return;
        }
        
        [strong_self completeWrite:write success:NO];
        
        if(write.isWriting) {
            [strong_self writeNext];
        }
    }];
    
    if(!self.socket.isConnected) {
        return write.writeID;
    }
    
    if(self.writesM.firstObject != write) {
        return write.writeID;
    }
    
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
    
    [self.writesM removeObject:write];
    return YES;
}

#pragma mark - Private
- (BOOL)connect {
    NSError *error = nil;
    return [self.socket connectToHost:self.host onPort:self.port error:&error];
}


- (void)writeNext {
    if(!self.writesM.count) {
        return;
    }
    
    AKSocketWrite *write = self.writesM.firstObject;
    if(write.isWriting) {
        return;
    }
    
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    if(write.expiredTime <= now) {
        [self completeWrite:write success:NO];
        return;
    }
    
    write.writing = YES;
    NSTimeInterval timeout = write.expiredTime - now;
    [self.socket writeData:write.data withTimeout:timeout tag:write.writeID];
}

- (void)completeWrite:(AKSocketWrite *)write success:(BOOL)success {
    if(!write) {
        return;
    }
    
    [self.writesM removeObject:write];
    AKAsyncSocketWriteComplete complete = write.complete;
    !complete ?: complete(success);
}

#pragma mark - GCDAsyncSocketDelegate

/**
 * Called when a socket connects and is ready for reading and writing.
 * The host parameter will be an IP address, not a DNS name.
 **/
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    if([self.delegate respondsToSelector:@selector(socketDidConnect:)]) {
        [self.delegate socketDidConnect:self];
    }
    
    self.reconnectTimes = 0;
    self.forceDisconnect = NO;
    
    if(self.isReadData) {
        [sock readDataWithTimeout:AKAsyncSocketTimeoutNever tag:self.readDataTimes++];
    }
    
    [self writeNext];
}

/**
 * Called when a socket has completed reading the requested data into memory.
 * Not called if there is an error.
 **/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    [self.delegate socket:self didReadData:data];
    [sock readDataWithTimeout:AKAsyncSocketTimeoutNever tag:self.readDataTimes++];
}

/**
 * Called when a socket has completed writing the requested data. Not called if there is an error.
 **/
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"writeID = %@", tag];
    AKSocketWrite *write = [self.writesM filteredArrayUsingPredicate:predicate].lastObject;
    [self completeWrite:write success:YES];
    
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
    if([self.delegate respondsToSelector:@selector(socketDidDisconnect:)]) {
        [self.delegate socketDidDisconnect:self];
    }
    
    if(self.isForceDisconnect) {
        return;
    }
    
    if(self.reconnectTimes <= 8) {
        self.reconnectTimes++;
    }
    [self performSelector:@selector(connect) withObject:nil afterDelay:pow(2, self.reconnectTimes)];
}

@end
