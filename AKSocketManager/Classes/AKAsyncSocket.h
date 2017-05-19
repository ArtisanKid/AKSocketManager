//
//  AKAsyncSocket.h
//  Pods
//
//  Created by 李翔宇 on 2017/1/1.
//
//

/*
 AKAsyncSocket是GCDAsyncSocket的包装，隐藏了底层三方框架细节，主要实现了：
 （1）支持单例模式
 （2）强制使用异步线程进行socket通信
 （3）支持取消信息发送
 （4）支持信息过期
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AKAsyncSocketWriteComplete) (BOOL success);

@protocol AKAsyncSocketDelegate;
@interface AKAsyncSocket : NSObject

//单例，用于快速管理Socket
@property (class, nonatomic, strong, readonly) AKAsyncSocket *socket;

@property (nonatomic, weak) id<AKAsyncSocketDelegate> delegate;

//重新连接必须先调用 disconnect 方法，否则重连失效
- (BOOL)connectToHost:(NSString *)host onPort:(uint16_t)port;
- (void)disconnect;


/**
 启动读取数据
 开始读取数据后，AKAsyncSocket会自动的循环读取数据
 获取到数据后，会通过socket:didReadData:协议方法通知业务方
 */
- (void)startReadData;

/**
 使用指定超时时间戳写入数据

 @param data 写入的数据
 @param time 超时时间戳
 @param complete void (^AKAsyncSocketWriteComplete) (BOOL success)
 @return 写入数据标识
 */
- (NSString *)writeData:(NSData *)data expiredTime:(NSTimeInterval)expiredTime complete:(AKAsyncSocketWriteComplete)complete;

/**
 取消数据写入

 @param writeID 写入数据标识
 @return 取消结果
 */
- (BOOL)cancelWrite:(NSString *)writeID;

@end

@protocol AKAsyncSocketDelegate <NSObject>

@optional
- (void)socketDidConnect:(AKAsyncSocket *)socket;
- (void)socketDidDisconnect:(AKAsyncSocket *)socket;

@required
- (void)socket:(AKAsyncSocket *)socket didReadData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
