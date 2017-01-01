//
//  AKSocketWrite.h
//  Pods
//
//  Created by 李翔宇 on 2017/1/1.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AKSocketWrite : NSObject

typedef void(^AKSocketWriteTimeout)(AKSocketWrite *write);

//将要写入的数据ID
@property (nonatomic, assign) NSUInteger writeID;

//将要写入的数据
@property (nonatomic, strong) NSData *data;

//超时秒数
@property (nonatomic, assign) NSTimeInterval timeout;

//创建时间戳
@property (nonatomic, assign) NSTimeInterval timestamp;

//更改操作状态
@property (atomic, assign, getter=isWriting) BOOL writing;

@property (nonatomic, strong) id complete;

- (void)monitorTimeout:(AKSocketWriteTimeout)timeout;

@end

NS_ASSUME_NONNULL_END
