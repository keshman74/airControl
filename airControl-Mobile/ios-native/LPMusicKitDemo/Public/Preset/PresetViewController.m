//  category: preset
//
//  PresetViewController.m
//  iMuzo
//
//  Created by Ning on 16/1/4.
//  Copyright © 2016年 wiimu. All rights reserved.
//

#import "PresetViewController.h"
#import "UIImageView+WebCache.h"
#import "DDXMLDocument.h"

@interface PresetViewController ()

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSString *> *presetPictures;
@property (nonatomic) NSUInteger presetRequest;
@property (nonatomic, copy) NSArray<NSNumber *> *serviceSlots;
@property (nonatomic,strong) NSArray *keyArray;//设备的预置列表

@end

@implementation PresetViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = UIColor.blackColor;
    self.tableView.backgroundColor = UIColor.blackColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = [UIColor colorWithWhite:.22 alpha:1];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 70, 0, 14);
    self.tableView.rowHeight = 64;
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.navigationBar.backgroundColor = UIColor.blackColor;
    [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.tintColor = UIColor.whiteColor;
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.whiteColor,
        NSFontAttributeName:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]}];
    [self getPresetStatus];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(BOOL)isNavigationBackEnabled
{
    return YES;
}

-(NSString *)navigationBarTitle
{
    return self.serviceSource.length ? self.serviceSource : [@"preset" uppercaseString];
}

-(BOOL)needBlurBack
{
    return NO;
}

#pragma mark - UITableViewDelegate && UITabelViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.serviceSource.length ? self.serviceSlots.count : self.keyArray.count;
}

- (NSInteger)presetIndexAtRow:(NSInteger)row {
    return self.serviceSource.length ? self.serviceSlots[row].integerValue : row;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (!self.serviceSource.length) return nil;
    return self.serviceSlots.count ?
        @"Воспроизведение использует сохранённый пресет и аккаунт колонки." :
        @"Пресеты сервиса не найдены. Сохраните альбом, плейлист или трек как пресет на этой колонке в её приложении.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSInteger presetIndex = [self presetIndexAtRow:indexPath.row];
    static NSString *kCellIdentifier = @"kCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (cell == nil){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier];
    }else{
        for(UIView * subview in [cell.contentView subviews]){
            [subview removeFromSuperview];
        }
    }
    cell.backgroundColor = [UIColor colorWithWhite:.055 alpha:1];
    cell.contentView.backgroundColor = [UIColor colorWithWhite:.055 alpha:1];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    UIView *selection = [UIView new]; selection.backgroundColor = [UIColor colorWithWhite:.14 alpha:1];
    cell.selectedBackgroundView = selection;
    LPPlayMusicList *musicList = self.keyArray[presetIndex];
    LPPlayHeader *header = musicList.header;
    
    //封面
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 8, 48, 48)];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 0, [UIScreen mainScreen].bounds.size.width-160, 64)];
    nameLabel.backgroundColor = [UIColor clearColor];
    nameLabel.textColor = [UIColor whiteColor];;
    nameLabel.text = [header.headTitle length] == 0?@"Пустой пресет":header.headTitle;
    nameLabel.font = [UIFont systemFontOfSize:16];

    //去除后缀
    if ([header.headTitle isEqualToString:RECENTLY_QUEUE])
    {
        nameLabel.text = @"preset_Recently_Played";
    }
    if ([header.headTitle hasPrefix:RECENTLY_QUEUE])
    {
        nameLabel.text = @"preset_Recently_Played";
    }
    else if ([header.headTitle hasPrefix:MyFavoriteQueueName])
    {
        nameLabel.text = @"preset_Favorites";
    }
    else if([header.headTitle hasPrefix:@"WiimuCustomList"])
    {
        NSArray *array = [header.headTitle componentsSeparatedByString:@"WiimuCustomList_"];
        nameLabel.text = [array lastObject];
    }
    else if ([header.mediaSource isEqualToString:SPOTIFY_SOURCE])
    {
        CGFloat labelw = self.view.frame.size.width-160;
        NSArray *array = [header.headTitle componentsSeparatedByString:@"_#~"];
        nameLabel.text = [array firstObject];
        nameLabel.frame = CGRectMake(70, 8, labelw, 25);
        UILabel * sublabel = [[UILabel alloc]initWithFrame:CGRectMake(70, 32, 150, 20)];
        sublabel.text = @"Spotify";
        sublabel.font = [UIFont systemFontOfSize:15];
        sublabel.textColor = [UIColor colorWithWhite:.68 alpha:1];
        [cell.contentView addSubview:sublabel];
    }
    else if ([header.headTitle rangeOfString:@"_#~"].location != NSNotFound && [header.headTitle length] > 0)
    {
        NSArray *array = [header.headTitle componentsSeparatedByString:@"_#~"];
        nameLabel.text = [array firstObject];
    }

    [cell.contentView addSubview:imageView];
    [cell.contentView addSubview:nameLabel];

    if ([header.headTitle length] > 0){
        imageView.image = [UIImage systemImageNamed:@"music.note"];
        imageView.tintColor = [UIColor colorWithWhite:.78 alpha:1];
        imageView.backgroundColor = [UIColor colorWithWhite:.16 alpha:1];
        imageView.layer.cornerRadius = 7;
    }else{
        imageView.image = nil;
        imageView.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
        imageView.layer.cornerRadius = 24;
        imageView.layer.borderWidth = 1;
        imageView.layer.borderColor = [UIColor colorWithWhite:.42 alpha:1].CGColor;
        UILabel *slot = [[UILabel alloc] initWithFrame:imageView.bounds];
        slot.text = [NSString stringWithFormat:@"%ld", (long)(presetIndex + 1)];
        slot.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        slot.textColor = [UIColor colorWithRed:1 green:.624 blue:.039 alpha:1];
        slot.textAlignment = NSTextAlignmentCenter;
        slot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [imageView addSubview:slot];
    }
    
    if (header.headTitle.length) {
        for (NSString *value in @[header.imageUrl ?: @"", musicList.list.firstObject.trackImage ?: @"", self.presetPictures[@(presetIndex + 1)] ?: @""]) {
            NSURLComponents *parts = [NSURLComponents componentsWithString:value];
            if (![@[@"http", @"https"] containsObject:parts.scheme.lowercaseString] || !parts.host.length || parts.user || parts.password) continue;
            [imageView sd_setImageWithURL:parts.URL placeholderImage:imageView.image];
            break;
        }
    }

    if ([header.headTitle length] > 0 && !self.isAddPreset && !self.isAddAlarmClock && !self.serviceSource.length) {
        UIButton *deleteButton = [[UIButton alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width - 84, 8, 72, 48)];
        [cell.contentView addSubview:deleteButton];
        [deleteButton setTitle:@"Удалить" forState:UIControlStateNormal];
        [deleteButton setTitleColor:[UIColor colorWithRed:1 green:.624 blue:.039 alpha:1] forState:UIControlStateNormal];
        deleteButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [deleteButton addTarget:self action:@selector(deleteButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        deleteButton.tag = 1000 + indexPath.row;
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 64;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.isAddPreset) {
        LPPlayMusicList *musicList = [[LPPlayMusicList alloc] init];
        musicList.header = self.header;
        musicList.list = @[self.item];
        musicList.index = (int)indexPath.row;
        musicList.account = self.account;
        
        NSDictionary *presetDict = [[LPMDPKitManager shared] updataPresetDataWithPlayMusicList:musicList devicePresetList:self.keyArray];
        LPDevice *device =[[LPDeviceManager sharedInstance] deviceForID:self.deviceId];
        LPDevicePreset *devicePreset = device.getPreset;
        
        [self showHud:@""];
        [devicePreset setPresetWithInfomation:presetDict completionHandler:^(BOOL isSuccess) {
            
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self hideHud:isSuccess ? @"Success":@"Fail" afterDelay:2 type:MBProgressHUDModeIndeterminate];
                 
                 if (isSuccess) {
                     [self getPresetStatus];
                 }
             });
        }];
    }else if (self.isAddAlarmClock){
        
        LPPlayMusicList *musicList = self.keyArray[indexPath.row];
        LPPlayHeader *header = musicList.header;
        if ([header.headTitle length] == 0) {
            
            [self.view makeToast:@"Preset content cannot be empty"];
            return;
        }
        
        if ([GlobalUI sharedInstance].alarmSourceObj.isEditingAlarmSource) {
        
            if ([[GlobalUI sharedInstance].alarmSourceObj.alarmRootViewController respondsToSelector:@selector(alarmPresetIndex:presetName:)])
            {
                [[GlobalUI sharedInstance].alarmSourceObj.alarmRootViewController alarmPresetIndex:(int)indexPath.row presetName:header.headTitle];
            }

            [[GlobalUI sharedInstance].alarmSourceObj.alarmRootViewController.navigationController popToViewController:[GlobalUI sharedInstance].alarmSourceObj.alarmRootViewController animated:YES];
            return;
        }
        
    }else{
        NSInteger presetIndex = [self presetIndexAtRow:indexPath.row];
        LPPlayMusicList *musicList = self.keyArray[presetIndex];
        LPPlayHeader *header = musicList.header;
        if ([header.headTitle length] == 0) {
            return;
        }
        
        [self showHud:@""];
        LPDevice *device =[[LPDeviceManager sharedInstance] deviceForID:self.deviceId];
        LPDevicePreset *devicePreset = device.getPreset;
        if (!devicePreset) { [self hideHud:@"Устройство недоступно" type:0]; return; }
        [devicePreset playPresetWithIndex:presetIndex + 1 completionHandler:^(BOOL isSuccess) {
            dispatch_async(dispatch_get_main_queue(), ^{
                 [self hideHud:isSuccess ? @"Success":@"Fail" afterDelay:2 type:MBProgressHUDModeIndeterminate];
             });
        }];
    }
}

- (void)deleteButtonAction:(UIButton *)action
{
    int index = (int)action.tag - 1000;
    NSDictionary *presetDict = [[LPMDPKitManager shared] deletePresetDataWithIndex:index devicePresetList:self.keyArray];
    
    [self showHud:@""];
    LPDevice *device =[[LPDeviceManager sharedInstance] deviceForID:self.deviceId];
    LPDevicePreset *devicePreset = device.getPreset;
    [devicePreset deletePresetWithInfomation:presetDict completionHandler:^(BOOL isSuccess) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHud:isSuccess ? @"Success":@"Fail" afterDelay:2 type:MBProgressHUDModeIndeterminate];
            if (isSuccess) {
                [self getPresetStatus];
            }
        });
    }];
}

#pragma mark -privateMethods
- (void)getPresetStatus
{
    NSString *identity = [self.deviceId copy];
    NSUInteger request = ++self.presetRequest;
    self.keyArray = @[];
    self.presetPictures = @{};
    self.serviceSlots = @[];
    [self.tableView reloadData];
    LPDevice *device = [[LPDeviceManager sharedInstance] deviceForID:identity];
    LPDevicePreset *devicePreset = device.getPreset;
    if (!devicePreset) return;
    [self showHud:@""];
    [devicePreset getPresets:^(int presetNumber, NSString * _Nullable presetString) {
       dispatch_async(dispatch_get_main_queue(), ^{
            if (request != self.presetRequest || ![identity isEqualToString:self.deviceId]) return;
            [self hideHud:@"" type:0];
            NSArray *list = [[LPMDPKitManager shared] getPresetListDataWithNumber:presetNumber presetString:presetString];
            self.keyArray = list ?: @[];
            if (self.serviceSource.length) {
                NSMutableArray *slots = [NSMutableArray array];
                [self.keyArray enumerateObjectsUsingBlock:^(LPPlayMusicList *preset, NSUInteger index, BOOL *stop) {
                    NSString *source = preset.header.mediaSource;
                    if (!source.length || !preset.header.headTitle.length) return;
                    BOOL matches = [source caseInsensitiveCompare:self.serviceSource] == NSOrderedSame;
                    BOOL modernDeezer = [self.serviceSource isEqualToString:@"Deezer"] &&
                        [source caseInsensitiveCompare:@"Deezer2"] == NSOrderedSame;
                    if (matches || modernDeezer) [slots addObject:@(index)];
                }];
                self.serviceSlots = slots;
            }
            NSMutableDictionary *pictures = [NSMutableDictionary dictionary];
            if (presetString.length && presetString.length < 4000000 &&
                [presetString rangeOfString:@"<!DOCTYPE" options:NSCaseInsensitiveSearch].location == NSNotFound) {
                DDXMLDocument *document = [[DDXMLDocument alloc] initWithXMLString:presetString options:0 error:nil];
                for (NSInteger slot = 1; slot <= self.keyArray.count; slot++) {
                    NSString *path = [NSString stringWithFormat:@".//*[local-name()='Key%ld']/*[local-name()='PicUrl']", (long)slot];
                    NSString *picture = [document nodesForXPath:path error:nil].firstObject.stringValue;
                    if (picture.length) pictures[@(slot)] = picture;
                }
            }
            self.presetPictures = pictures;
            [self.tableView reloadData];
        });
    }];
}

- (NSString *)stringFromDate:(NSDate *)date
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *destDateString = [dateFormatter stringFromDate:date];
    return destDateString;
}

@end
