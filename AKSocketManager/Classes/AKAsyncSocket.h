//
//  AKAsyncSocket.h
//  Pods
//
//  Created by 李翔宇 on 2017/1/1.
//
//

/*
 确定AKSocketManager要做的事情
 （1）隐藏三方库细节
 （2）统一三方库回调
 （3）支持单例模式
 （4）强制使用异步线程
 （5）支持取消发送
 （5）更少的接口
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AKAsyncSocketWriteComplete) (BOOL success);

@protocol AKAsyncSocketDelegate;
@interface AKAsyncSocket : NSObject

//单例，用于快速的管理Socket
@property (class, nonatomic, strong) AKAsyncSocket *socket;

@property (nonatomic, weak) id<AKAsyncSocketDelegate> delegate;

//重新连接必须先调用 disconnect 方法，否则重连失效
- (BOOL)connectToHost:(NSString *)host onPort:(uint16_t)port;
- (void)disconnect;

- (void)startReadData;

/**
 使用指定超时时间戳写入数据

 @param data 写入的数据
 @param time 超时时间戳
 @param complete void (^AKAsyncSocketWriteComplete) (BOOL success)
 @return 写入数据标识
 */
- (NSString *)writeData:(NSData *)data expiredTime:(NSTimeInterval)time complete:(AKAsyncSocketWriteComplete)complete;

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
