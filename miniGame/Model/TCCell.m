//
//  Cell.m
//  TCCollision
//
//  Created by Daniel Feltey on 5/12/11.
//  Copyright 2011 University of Chicago. All rights reserved.
//

#import "TCCell.h"


@implementation TCCell
@synthesize infected,emitted,infection_prob,bind_pos,dest_pos,replication_time; //cell_sprite;


-(id) init 
{
    self = [super init];
    if(self)
    {
    
    self.infected = NO;
    self.emitted = NO;
    self.infection_prob = arc4random()%3;
    self.bind_pos = ccp(0,0);
    self.dest_pos = ccp(0,0);
    self.replication_time = 0;
    
    }
    return self;
    
}

- (float) distance_from_cell: (TCCell *) cell
{
    float distance;
    float x = self.bind_pos.x - cell.bind_pos.x;
    float y = self.bind_pos.y - cell.bind_pos.y;
    distance = sqrtf(powf(x, 2)+powf(y, 2));
    return distance;
}


- (void) get_new_dest
{

    float x = self.bind_pos.x + (arc4random() % (2*MVMNT_RAD)) - MVMNT_RAD;
    float y = self.bind_pos.y + (arc4random() % (2*MVMNT_RAD)) - MVMNT_RAD;
    
    self.dest_pos = ccp(x,y); 
}


// dealloc
-(void) dealloc
{
    [super dealloc];
}

@end












