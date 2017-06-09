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
@property (nonatomic, strong) NSString *writeID;

//将要写入的数据
@property (nonatomic, strong) NSData *data;

//超时时间戳
@property (nonatomic, assign) NSTimeInterval expiredTime;

//创建时间戳
@property (nonatomic, assign) NSTimeInterval createdTime;

//开始写入时间戳
@property (nonatomic, assign) NSTimeInterval activeTime;

//完成写入时间戳
@property (nonatomic, assign) NSTimeInterval completeTime;

//更改操作状态
@property (atomic, assign, getter=isWriting) BOOL writing;

@property (nonatomic, strong) id complete;

@end

NS_ASSUME_NONNULL_END
