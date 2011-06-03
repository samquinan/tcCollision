//
//  Cell.h
//  TCCollision
//
//  Created by Daniel Feltey on 5/12/11.
//  Copyright 2011 University of Chicago. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"
#import <math.h>

#define RADIUS 22
#define MVMNT_RAD 11


@interface TCCell : NSObject {
    
    
    BOOL infected;
    BOOL emitted;
    int infection_prob; 
    CGPoint bind_pos;
    CGPoint dest_pos; 
    float replication_time; 

    
}
-(float) distance_from_cell: (TCCell *) cell;
// calculate the distance between two cells


- (void) get_new_dest;


@property (nonatomic) BOOL infected;
@property (nonatomic) BOOL emitted;
@property (nonatomic) int infection_prob;
@property (nonatomic) CGPoint bind_pos;
@property (nonatomic) CGPoint dest_pos;
@property (nonatomic) float replication_time;

@end
