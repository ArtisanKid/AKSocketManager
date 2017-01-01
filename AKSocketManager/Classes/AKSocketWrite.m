//
//  AKSocketWrite.m
//  Pods
//
//  Created by 李翔宇 on 2017/1/1.
//
//

#import "AKSocketWrite.h"

@interface AKSocketWrite ()

@property (nonatomic, strong) dispatch_source_t timer;

@end

@implementation AKSocketWrite

- (void)dealloc {
    dispatch_source_cancel(_timer);
}

- (void)monitorTimeout:(AKSocketWriteTimeout)timeout {
    if(self.timer) {
        return;
    }
    
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, DISPATCH_TIMER_STRICT, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, DISPATCH_TIME_FOREVER, 0);
    __weak typeof(self) weak_self = self;
    dispatch_source_set_event_handler(self.timer, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weak_self) strong_self = weak_self;
            !timeout ? : timeout(strong_self);
        });
    });
    dispatch_resume(self.timer);
}

@end
