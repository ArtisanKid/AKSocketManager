//
//  AKEncoder.h
//  Pods
//
//  Created by 李翔宇 on 2017/6/15.
//
//

#import <Foundation/Foundation.h>

@interface AKEncoder : NSObject

/**
 将body长度值以Varint32方式编码

 @param bodyLength 消息主体长度
 @return 编码结果
 */
+ (NSData *)ak_writeRawVarint32:(NSUInteger)bodyLength;

/**
 从body中以Varint32方式解码出body长度值

 @param data 消息数据
 @param count 消息头占用的字节数
 @return 解码结果
 */
+ (NSUInteger)ak_readRawVarint32:(NSData *)data byteCount:(NSUInteger *)count;

@end
