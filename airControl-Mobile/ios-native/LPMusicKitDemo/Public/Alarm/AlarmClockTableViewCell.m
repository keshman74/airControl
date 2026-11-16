//  category: alarm
//
//  AlarmClockTableViewCell.m
//  iMuzo
//
//  Created by Ning on 15/4/9.
//  Copyright (c) 2015年 wiimu. All rights reserved.
//

#import "AlarmClockTableViewCell.h"

@implementation AlarmClockTableViewCell

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.timeLabel.font = [UIFont systemFontOfSize:17];
    self.timeLabel.textColor = [UIColor whiteColor];
    self.rateLabel.font = [UIFont systemFontOfSize:17];
    self.rateLabel.textColor = [UIColor lightGrayColor];;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
