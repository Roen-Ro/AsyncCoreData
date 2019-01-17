//
//  RRViewController.m
//  AsyncCoreData
//
//  Created by zxllf23@163.com on 01/12/2019.
//  Copyright (c) 2019 zxllf23@163.com. All rights reserved.
//

#import "RRViewController.h"
#import <AsyncCoreData/AsyncCoreData.h>
#import "PlaceModel.h"

#define PLACE_ENTITY @"PlaceEntity"

#define DB_PLACE QUERY_ENTITY(PLACE_ENTITY)

@interface RRViewController ()
@property (nonatomic, strong) AsyncCoreData *dbManager;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segControl;
@property (nonatomic, copy) NSString *SubFixStr;

@end

@implementation RRViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
 //   self.segControl.selectedSegmentIndex = 1;
    [self dataStoreChange:self.segControl];
    [self initialDataMap];

}
-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

-(void)initialDataMap {
    [AsyncCoreData setModelToDataBaseMapper:^(PlaceModel * model, NSManagedObject * _Nonnull managedObject) {
        [managedObject setValue:model.zipCode forKey:@"uniqueID"];
        [managedObject setValue:model.name forKey:@"name"];
        [managedObject setValue:model.country forKey:@"country"];
        [managedObject setValue:@(model.level) forKey:@"level"];
    } forEntity:PLACE_ENTITY];
    
    [AsyncCoreData setModelFromDataBaseMapper:^__kindof NSObject * _Nonnull(PlaceModel * _Nullable model, NSManagedObject * _Nonnull managedObject) {
        if(!model)
            model = [PlaceModel new];
        model.zipCode = [managedObject valueForKey:@"uniqueID"];
        model.name = [managedObject valueForKey:@"name"];
        model.country = [managedObject valueForKey:@"country"];
        model.level = [[managedObject valueForKey:@"level"] intValue];
        
        return model;
    } forEntity:PLACE_ENTITY];
}

- (IBAction)dataStoreChange:(UISegmentedControl *)sender {
    
    NSString *name = [sender titleForSegmentAtIndex:sender.selectedSegmentIndex];
    NSURL *docUrl = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *dataBaseFileUrl = [docUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",name]];
    
    [AsyncCoreData setPersistantStore:dataBaseFileUrl withModel:@"RRCDModel" completion:^{
        NSLog(@"Data Base changed to %@",name);

    }];
    
      self.SubFixStr = [self.segControl titleForSegmentAtIndex:self.segControl.selectedSegmentIndex];
}

-(IBAction)changeToCurrentStore:(id)sender {
    [self dataStoreChange:self.segControl];
}





-(NSArray *)dataToWrite {
    
    PlaceModel *m1 = [PlaceModel new];
    m1.name = @"吉安";
    m1.country = @"China";
    m1.level = 4;
    m1.zipCode = [NSString stringWithFormat:@"%@-C001",self.SubFixStr];
    
    PlaceModel *m2 = [PlaceModel new];
    m2.name = @"南昌";
    m2.country = @"China";
    m2.level = 3;
    m2.zipCode = [NSString stringWithFormat:@"%@-C002",self.SubFixStr];
    
    PlaceModel *m3 = [PlaceModel new];
    m3.name = @"帝都";
    m3.country = @"China";
    m3.level = 1;
    m3.zipCode = [NSString stringWithFormat:@"%@-C003",self.SubFixStr];
    
    PlaceModel *m4 = [PlaceModel new];
    m4.name = @"London";
    m4.country = @"British";
    m4.level = 1;
    m4.zipCode = [NSString stringWithFormat:@"%@-E001",self.SubFixStr];
    
    PlaceModel *m5 = [PlaceModel new];
    m5.name = @"NewYork";
    m5.country = @"USA";
    m5.level = 1;
    m5.zipCode = [NSString stringWithFormat:@"%@-A001",self.SubFixStr];
    
    PlaceModel *m6 = [PlaceModel new];
    m6.name = @"Not Found";
    m6.country = @"Outter Space";
    m6.level = 1;
    m6.zipCode = nil;
    
    return @[m1,m2,m3,m4,m5,m6];
}

- (IBAction)writeData:(id)sender {
    
    NSError *e = [DB_PLACE saveModels:[self dataToWrite]];
    NSLog(@"writeData finished with error %@",e);
}

- (IBAction)readData:(id)sender {
    
    NSArray *results =  [DB_PLACE modelsWithPredicate:[NSPredicate predicateWithFormat:@"country = \"China\""] inRange:NSMakeRange(0, 999) sortByKey:nil reverse:YES];
    NSLog(@"readData:%@",results);
}


- (IBAction)writeDataAsync:(id)sender {

    [DB_PLACE saveModelsAsync:[self dataToWrite] completion:^(NSError *e) {
        NSLog(@"writeDataAsync finished with error %@",e);
    }];

}
- (IBAction)readDataAsync:(id)sender {
    
    [DB_PLACE modelsWithPredicateAsync:[NSPredicate predicateWithFormat:@"country = \"China\""] inRange:NSMakeRange(0, 999) sortByKey:nil reverse:NO completion:^(NSArray *results) {
        
        NSLog(@"readDataAsync:%@",results);
    }];

}

-(IBAction)clearAllData:(id)btn {
    
    for(int i=0; i<3;i++) {
        NSError *error;
        NSString *name = [self.segControl titleForSegmentAtIndex:self.segControl.selectedSegmentIndex];
        NSURL *docUrl = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        NSURL *dataBaseFileUrl = [docUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",name]];
        [[NSFileManager defaultManager] removeItemAtURL:dataBaseFileUrl error:&error];
        NSLog(@"Remove %@ error %@",[dataBaseFileUrl lastPathComponent],error);
    }
}

#define COUNT 1000

-(PlaceModel *)newPlaceModel {
    
    PlaceModel *m = [PlaceModel new];
    m.name = @"city test";
    m.country = @"British";
    m.level = 18;
    m.zipCode = nil;
    return m;
}



@end
