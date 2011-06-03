//
//  TC_Game.h
//  TCCollision
//
//  Created by Daniel Feltey on 5/15/11.
//  Copyright 2011 University of Chicago. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"
#import <math.h>
#import "TCCell.h"
#import <stdio.h>
#import <stdlib.h>

#define NUM_INIT 50 
#define INFECTED_INIT 3 
#define X_DIM   480
#define Y_DIM   320
#define THRESHOLD 20
#define CK_RAD 90 


@interface TCGame : NSObject {
    
    
    NSMutableArray *cells;
    NSMutableArray *cur_infected;
    int num_infected;
    int num_remaining;
    
}

- (void) kill_cell: (TCCell *) cell;
// update remaining
// release cell
// if infected subtract from num_infected

- (void) spread_infection: (TCCell *) cell;



- (NSMutableArray *) cells_near_point: (CGPoint) p; 

@property (nonatomic, retain) NSMutableArray *cells;
@property (nonatomic, retain) NSMutableArray *cur_infected;
@property (nonatomic) int num_infected;
@property (nonatomic) int num_remaining;

@end
