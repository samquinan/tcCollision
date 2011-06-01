//
//  HelloWorldLayer.m
//  miniGame
//
//  Created by Sam Quinan on 5/12/11.
//  Copyright University of Chicago 2011. All rights reserved.
//


// Import the interfaces
#import "TCCollisionLayer.h"
#import "CCTouchDispatcher.h"
#import "TCGame.h"
#import "TCCell.h"
#import "SimpleAudioEngine.h"

// Macro Definitions
#define TOUCH_THRESHOLD 20 // how close a cell sprite must be to the touch for it to be considered tapped
#define CELL_RADIUS 21 // the radius of the cell graphic
#define CD8_V 0.2/100 // velocity value used in keeping the CD8 cell moving at a constant speed
#define REG_V 5 // velocity value used to keep the regular cells moving around at a constant speed
#define OFFSET 25 // how far off screen chemokine signaled cd8 cells are initialized
#define ARC4RANDOM_MAX 0x100000000 // mav value returned by arc4random() call

// generates a random float between 0 and 1 bsed of the arc4random() random number generator
static inline double randf(){
    return (double)arc4random() / ARC4RANDOM_MAX;
}

// linearly interpolates between two values 'a' and 'b' when given a float 't' in the range [0,1]. 
//      returns 'a' if 't' = 0, 'b' if 't' = 1, and a linear combination otherwise.
static inline double lerp(double a, double b, double t)
{
    return a + (b - a) * t;
}

// HelloWorldLayer implementation
@implementation TCCollisionLayer
@synthesize sprites, objects, spriteSheet, CD8;

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	TCCollisionLayer *layer = [TCCollisionLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}


// takes 2 CG points (cur and dst) and returns a normalized 2D vector (represented in memory as a CGPoint) pointing from the first (cur) to the second (dst)
-(CGPoint) getVectorFromPoint:(CGPoint) cur ToPoint:(CGPoint) dst{
    CGPoint vec;
    double len = sqrt(((dst.x - cur.x) * (dst.x - cur.x)) + ((dst.y - cur.y) * (dst.y - cur.y)));
    if (len != 0.0){
        vec.x = (dst.x - cur.x)/len;
        vec.y = (dst.y - cur.y)/len;
        return vec;
    }
    else{
        return ccp(0,0);
    }
}

// convenience method for setting up and keeping track of all the cell sprites within the scene
-(void)setupSprites
{
    // initialization of hacked connection tracking
    self.sprites = [NSMutableArray new];
    self.objects = [NSMutableArray new];
    
    //init spriteSheet
    [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"spriteSheet.plist"];
    spriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"spriteSheet.png"];
    [self addChild:spriteSheet];
    
    //for each cell in the game object
    for (id obj in game.cells){
        TCCell *next = obj;
        //create a new sprite, place it at it's bind position, and add objects to arrays to keep track of model/sprite connections 
        CCSprite *cellSprite = [CCSprite spriteWithSpriteFrameName:@"TCR_YCell.png"];
        cellSprite.position = next.bind_pos;
        [spriteSheet addChild: cellSprite];
        [sprites addObject:cellSprite];
        [objects addObject:next];
    }
    
    CGSize s = [[CCDirector sharedDirector] winSize];
    //init main char at center of the screen
    CD8 = [CCSprite spriteWithSpriteFrameName:@"TCR_GCell.png"];
    CD8.position = ccp( s.width/2, s.height/2 );
    [spriteSheet addChild: CD8];
    
}

// on "init" you need to initialize your instance
-(id) init
{
	// always call "super" init
	// Apple recommends to re-assign "self" with the "super" return value
	if( (self=[super initWithColor:ccc4(189, 227, 219, 255)])) {
		
        //initialize game model
        game = [[TCGame alloc] init];
        
        //sound setup
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"Bing2.mp3"];
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"Alert.wav"];
        
        [self setupSprites];
        chemokinesReleased = NO;
        
        //setup score labels
        // note: need to keep references to the total and infected labels because those will be updated throughout the game, where as the segement will remain constant - simply add it to the layer; it will be released when the Layer is released.
        CGSize s = [[CCDirector sharedDirector] winSize];
        totalLabel = [[CCLabelBMFont labelWithString:[NSString stringWithFormat:@"%i",game.num_remaining] fntFile:@"Times32.fnt"] retain];
        totalLabel.position = ccp((s.width - 32),(s.height - 32));
        totalLabel.color = ccBLACK;
        [self addChild:totalLabel];
        
        CCLabelBMFont *segment = [CCLabelBMFont labelWithString:@":" fntFile:@"Times32.fnt"];
        segment.position = ccp((s.width - 32*(2)),(s.height - 29));
        segment.color = ccBLACK;
        [self addChild:segment];
        
        infectedLabel = [[CCLabelBMFont labelWithString:[NSString stringWithFormat:@"%i",game.num_infected] fntFile:@"Times32.fnt"] retain];
        infectedLabel.position = ccp((s.width - 32*(3)),(s.height - 32));
        infectedLabel.color = ccRED;
        [self addChild:infectedLabel];
                
        // schedule a repeating callback on every frame
        [self schedule:@selector(nextFrame:)];
        
        //enable touch
        self.isTouchEnabled = YES;
        
        // initialize vaiables for tracking user kills, tracking the length game play (for time bonus score), and ensuring that the game's end-screen only renders once (there were some runs where if you kill the last 2 cells fast enough both of them will trigger and pass the checkWinLose method - addition of simple boolean variable ensures this doesn't happen).
        killed = 0;
        gameOver = NO;
        timeBegin = [[NSDate date] timeIntervalSince1970];
	}
	return self;
}

// required method for registering touch events
-(void) registerWithTouchDispatcher
{
	[[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
}

// method that checks for game over conditions and in the case that they pass, displays the player's score. This will need to be updated to interface with the menu-based scoring syatem when it eventually gets implemented.
//        SCORING: user is given 10 points for every scoring-cell they kill (cells killed through chemokine signaling are non-scoring), 15 points for every non-infected cell saved, and 5 points for every second under 60 seconds that it takes the user to complete the game.
-(void) checkWinLose
{
    if ((game.num_infected == game.num_remaining) || (game.num_infected == 0)){ // game over conditions
        if (!gameOver){ // ensures end-screen scores only rendered once
            gameOver = YES;
            self.isTouchEnabled = NO;
            
            // display scores for user
            CGSize s = [[CCDirector sharedDirector] winSize];
            CGPoint center = ccp(s.width/2,s.height/2);
        
            int killScore = killed * 10;
            CCLabelBMFont *killScoreLabel = [CCLabelBMFont labelWithString:[NSString stringWithFormat:@"%i Killed x 10 = %i",killed, killScore] fntFile:@"Times32.fnt"];
            killScoreLabel.position = ccp(center.x, center.y + 40);
            killScoreLabel.color = ccBLACK;
            killScoreLabel.opacity = 0;
            [self addChild:killScoreLabel];
            [killScoreLabel runAction:[CCFadeTo actionWithDuration:0.5f opacity:255]];
        
            int numSaved = game.num_remaining;
            int savedScore = numSaved * 15;
            CCLabelBMFont *savedScoreLabel = [CCLabelBMFont labelWithString:[NSString stringWithFormat:@"%i Saved x 15 = %i", numSaved, savedScore] fntFile:@"Times32.fnt"];
            savedScoreLabel.position = center;
            savedScoreLabel.color = ccBLACK;
            savedScoreLabel.opacity = 0;
            [self addChild:savedScoreLabel];
            [savedScoreLabel runAction:[CCFadeTo actionWithDuration:0.5f opacity:255]];
         
            double timeElapsed = [[NSDate date] timeIntervalSince1970] - timeBegin;
            double timeBonus = MAX((60.0 - timeElapsed), 0.0);
            int timeScore = round(timeBonus * 5);
            CCLabelBMFont *timeScoreLabel = [CCLabelBMFont labelWithString:[NSString stringWithFormat:@"%.2f Time Bonus x 5 = %i", timeBonus, timeScore] fntFile:@"Times32.fnt"];
            timeScoreLabel.position = ccp(center.x, center.y - 40);
            timeScoreLabel.color = ccBLACK;
            timeScoreLabel.opacity = 0;
            [self addChild:timeScoreLabel];
            [timeScoreLabel runAction:[CCFadeTo actionWithDuration:0.5f opacity:255]];
        
            int totalScore = killScore + savedScore + timeScore;
            CCLabelBMFont *totalScoreLabel = [CCLabelBMFont labelWithString:[NSString stringWithFormat:@" TOTAL = %i", totalScore] fntFile:@"Times32.fnt"];
            totalScoreLabel.position = ccp(center.x, center.y - 80);
            totalScoreLabel.color = ccRED;
            totalScoreLabel.opacity = 0;
            [self addChild:totalScoreLabel];
            [totalScoreLabel runAction:[CCFadeTo actionWithDuration:0.5f opacity:255]];
        }
    }
}


// repeating callback on every frame rendering; is responsible for regular cell movement animations and infection propogation
- (void) nextFrame:(ccTime)dt {
    //cell animations
    //FOR EACH CELL
    for (id obj in sprites){
        // get corresponding model object for the sprite
        CCSprite *spriteCell = obj;
        TCCell *cellModel = [objects objectAtIndex:[sprites indexOfObject:spriteCell]];
        
        //get vector from current position to dst position
        CGPoint direction = [self getVectorFromPoint:spriteCell.position ToPoint:cellModel.dest_pos];
        
        //if not moving (either initially or having reached it's destination), get a new destination
        if (CGPointEqualToPoint(cellModel.dest_pos, ccp(0,0)) || ccpFuzzyEqual(spriteCell.position, cellModel.dest_pos, 0.2)){
            [cellModel get_new_dest];
            direction = [self getVectorFromPoint:spriteCell.position ToPoint:cellModel.dest_pos];
        }
        
        //update current position of the sprite
        spriteCell.position = ccp( spriteCell.position.x + direction.x*REG_V*dt, spriteCell.position.y + direction.y*REG_V*dt);
    }
    //END
    
    // decrement infection timers on any infected cells by time passed since the last update; if timer runs out (hits or passes 0), spread the infection, inform the user by updating label with the new number of infected cells on the screen, and check for game end conditions
    float delta = (float)dt;
    NSArray *updateList = game.cur_infected;
    for (id obj in updateList){
        TCCell *current = obj;
        current.replication_time -= delta;
        if (current.replication_time <= 0){
            [game spread_infection:current];
            [infectedLabel setString:[NSString stringWithFormat:@"%i", game.num_infected]];
            [self checkWinLose];
        }
    }
}

// method logs the beginning of a touch event
- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    return YES;
}

// method logs the end of a touch event; determines whether a touch even is a single or double tap and calls appropriate convenience method
- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    // stop any current actions being performed by the CD8 t-cell object
    [CD8 stopAllActions];
    // get location of the touch
	CGPoint location = [self convertTouchToNodeSpace: touch];
    
    switch (touch.tapCount){
        case 3:
            break;// does nothing on triple tap, ie. a triple tap remains registered as a double tap, rather than a double tap folllowed by a single tap or vice versa
        case 2:
            //on double tap (note: uses location registered by first tap)
            //cancel previously registered single tap behavior
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(singleTap)  object:nil];
            //call doubleTap convenience method
            [self performSelector:@selector(doubleTap)];
            break;
        case 1:
        default:
            //on single tap
            //register touch location
            singleTapLocation = location;
            //call singleTap convenience method
            [self performSelector:@selector(singleTap) withObject:nil afterDelay:0.0];
    }
    
}

// single tap comvenience method - determines if user has tapped a sprite, if so move to the cell's location and kill it if it is infected; else simply move to the specified location
-(void)singleTap
{
    BOOL objectFound = NO;
    for (id object in sprites) { // for each cell sprite on the screen
        CCSprite *current = object;
        TCCell *model = [objects objectAtIndex:[sprites indexOfObject:object]];
        //determine if the sprite has position coordintes within the touch threshold of the user's tap
        if ( (abs(current.position.x - singleTapLocation.x) < TOUCH_THRESHOLD) && (abs(current.position.y - singleTapLocation.y) < TOUCH_THRESHOLD)){
            // if yes
            objectFound = YES;
            // determine the distance from the CD8 cell's location to it's target location (i.e. the selected cell's position)
            CGPoint curPos = current.position;
            double len = sqrt(((CD8.position.x - curPos.x) * (CD8.position.x - curPos.x)) + ((CD8.position.y - curPos.y) * (CD8.position.y - curPos.y)));
            // determine time the movement animation should take given the CD8 cell's constant velocity and the distance that must be traveled
            float time = len * CD8_V;
            if (len != 0){
                //use normalized vector to determine the exact target location for CD8 cell (want CD8 cell to wind up in a positio that approximates a kiss-of-death)
                float dx = (CD8.position.x - curPos.x)/len;
                float dy = (CD8.position.y - curPos.y)/len;
                CGPoint target;
                target.x = round(curPos.x + dx*1.75*CELL_RADIUS);
                target.y = round(curPos.y + dy*1.75*CELL_RADIUS);
                // sequence actions
                NSMutableArray *actions = [NSMutableArray new];
                // move CD8 to touch the selected cell
                [actions addObject:[CCMoveTo actionWithDuration:time position:target]];
                if (model.infected){ // in the cell is infected
                    [actions addObject:[CCCallBlock actionWithBlock:^{
                        //increment user kill count
                        killed++;
                        //kill cell by calling induceCellDeath passing the selected sprite as an argument
                        [self performSelector:@selector(induceCellDeath:) withObject:current afterDelay:.1];
                    }]];
                }
                // run sequenced actions
                [CD8 runAction:[CCSequence actionsWithArray:actions]];
                [actions release];
            }
            // break loop if a sprite is found within the touch threshold of the tap
            break;
        }
    }
    if (!objectFound){
        // otherwise (no sprite at tap location)
        // move CD8 cell to tap location
        double len = sqrt(((CD8.position.x - singleTapLocation.x) * (CD8.position.x - singleTapLocation.x)) + ((CD8.position.y - singleTapLocation.y) * (CD8.position.y - singleTapLocation.y)));
        float time = len * CD8_V;
        [CD8 runAction:[CCMoveTo actionWithDuration:time position:singleTapLocation]];
    }
}

// convenience method for handling the double taps
-(void)doubleTap
{
    // if the double tap is located within 1.5 x the touch threshold of the location of the last killed cell (without an exact target for the user to tap, we need to provide some additional leniency), trigger chemokine signaling (at the the location of the last killed cell)
    if ((abs(chemokineReleaseCoords.x - singleTapLocation.x) < (TOUCH_THRESHOLD * 1.5)) && 
        (abs(chemokineReleaseCoords.y - singleTapLocation.y) < (TOUCH_THRESHOLD * 1.5))){
            [self performSelector:@selector(chemokineSignal) withObject:nil afterDelay:.1];
    }
}


// method takes a pointer to the CCSprite object for a regular cell in the game reperesentation and induces "apoptosis" / kills the cell off
-(void)induceCellDeath:(CCSprite *)cell
{
    // ensure the sprite object is corresponds to a regular cell
    if ([sprites containsObject:cell]){
        // get the sprite's corresponding model object
        TCCell *model = [objects objectAtIndex:[sprites indexOfObject:cell]];
    
        //create blinking animation
        NSMutableArray *blinkAnimFrames = [NSMutableArray array];
        [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_RCell.png"]]];
        [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_YCell.png"]]];
        [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_RCell.png"]]];
        [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_YCell.png"]]];
        [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_RCell.png"]]];
        [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_YCell.png"]]];
        [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_RCell.png"]]];
        CCAnimation *blinkAnimation = [CCAnimation animationWithFrames:blinkAnimFrames];
        CCAnimate *blink = [CCAnimate actionWithDuration:0.7f animation:blinkAnimation restoreOriginalFrame:NO];
        //create the apoptosis sequence
        CCSequence *die = [CCSequence actions:
                                                // kill the cell off inside the actual game model
                                                [CCCallBlock actionWithBlock:^{ [game kill_cell:model]; }],
                                                // call the blink animation
                                                blink,
                                                // simulatneously scale the sprite down, fade the sprite out, and play the appropriate sound effect
                                                [CCSpawn actions:   [CCScaleTo actionWithDuration:0.5f scale:0], 
                                                                    [CCFadeTo actionWithDuration:0.5f opacity:0],
                                                                    [CCCallBlock actionWithBlock:^{ [[SimpleAudioEngine sharedEngine] playEffect:@"Bing2.mp3"]; }], 
                                                                    nil],
                                                // remove the sprite from the screen, unlink the sprite and model, update labels to reflect the new game state, and check for game end
                                                [CCCallBlock actionWithBlock:^{ [spriteSheet removeChild:cell cleanup:YES];
                                                                                [sprites removeObject:cell];
                                                                                [objects removeObject:model];
                                                                                [infectedLabel setString:[NSString stringWithFormat:@"%i", game.num_infected]];
                                                                                [totalLabel setString:[NSString stringWithFormat:@"%i", game.num_remaining]];
                                                                                [self checkWinLose];
                                                                            }],
                                                nil
                           ];
    
        //log location for chemokine release
        chemokineReleaseCoords = cell.position;
        // chemokines have not been released yet for this location
        chemokinesReleased = NO;
    
        //run apoptosis sequence on the specified cell sprite
        [cell runAction:die];
    }
}


// chemokine signaling is a convenience method that creates a pair of helper CD8 t-cells which swoop in from off screen, check all of the cells within a given radius of the last user-killed cell, and kill any infected cells which they encounter (infected cells killed by this method to not count toward the user's score) -- will only run once for each user-killed cell
-(void)chemokineSignal
{
    //ensure only runs once
    if (!chemokinesReleased){

        chemokinesReleased = YES;
        
        //generate helper cd8 t-cell coordinates (based on which quarter of the screen the chemokines are being released in)
        CGPoint hLCoords;
        CGPoint hRCoords;
        
        CGSize s = [[CCDirector sharedDirector] winSize];
        if (chemokineReleaseCoords.x < s.width/2){
            hLCoords.x = -OFFSET;
            hRCoords.x = round(lerp(0.0, s.width/2, randf()));
        }
        else{
            hLCoords.x = s.width + OFFSET;
            hRCoords.x = round(lerp(s.width/2, s.width, randf()));
        }
        
        if (chemokineReleaseCoords.y < s.height/2){
            hLCoords.y = round(lerp(0.0, s.height/2, randf()));
            hRCoords.y = -OFFSET;
        }
        else{
            hLCoords.y = round(lerp(s.height/2, s.height, randf()));
            hRCoords.y = s.height + OFFSET;
        }
        
        //initialize helper cd8 t-cells offscreen
        CCSprite *hLCell = [CCSprite spriteWithSpriteFrameName:@"TCR_GCell.png"];
        hLCell.position = hLCoords;
        [spriteSheet addChild:hLCell];
        
        CCSprite *hRCell = [CCSprite spriteWithSpriteFrameName:@"TCR_GCell.png"];
        hRCell.position = hRCoords;
        [spriteSheet addChild:hRCell];
        
        // get all cells within a given radius of the last user-killed cell
        NSArray *tmp = [game cells_near_point:chemokineReleaseCoords];
        
        //tmp variables
        CGPoint current;
        float time;
        double len;
        
        // queue left helper cell actions:
        current = hLCoords;
        NSRange leftRange;
        leftRange.location = 0;
        leftRange.length = [tmp count]/2;
        NSArray *left = [tmp subarrayWithRange:leftRange];
        NSMutableArray *leftActions = [[NSMutableArray alloc] initWithCapacity:1];
        // for each model object in the first half of the array
        for (id obj in left){
            TCCell *model = obj;
            // get corresponding sprite
            CCSprite *next = [sprites objectAtIndex:[objects indexOfObject:model]];
            //calculate target point and animation time
            len = sqrt(((current.x - next.position.x) * (current.x - next.position.x)) + ((current.y - next.position.y) * (current.y - next.position.y)));
            time = len * CD8_V;
            CGPoint target;
            target.x = round(next.position.x + (current.x - next.position.x)*1.75*CELL_RADIUS/len);
            target.y = round(next.position.y + (current.y - next.position.y)*1.75*CELL_RADIUS/len);
            // add move to action queue
            [leftActions addObject:[CCMoveTo actionWithDuration:time position:target]];
            if (model.infected){
                // if the cell is infected, induce cell death (without adding to 'killed' count)
                [leftActions addObject:[CCCallBlock actionWithBlock:^{
                                            [self performSelector:@selector(induceCellDeath:) withObject:next afterDelay:.1];
                                        }]];
            }
            // add a short delay to help with flow of the animation
            [leftActions addObject:[CCDelayTime actionWithDuration:.4]];
            // store new future position for use in queuing next move
            current = next.position;
        }
        // cell leaves screen 
        len = sqrt(((current.x - hRCoords.x) * (current.x - hRCoords.x)) + ((current.y - hRCoords.y) * (current.y - hRCoords.y)));
        time = len * CD8_V;
        [leftActions addObject:[CCMoveTo actionWithDuration:time position:hRCoords]];
        
        // queue right helper cell actions:
        // cell traverses cloud
        current = hRCoords;
        NSRange rightRange;
        rightRange.location = [tmp count]/2;
        rightRange.length = [tmp count] - ([tmp count]/2);
        NSArray *right = [tmp subarrayWithRange:rightRange];
        // for each model object in the second half of the array
        NSMutableArray *rightActions = [[NSMutableArray alloc] initWithCapacity:1];
        for (id obj in right){
            TCCell *model = obj;
            // get corresponding sprite
            CCSprite *next = [sprites objectAtIndex:[objects indexOfObject:model]];
            //calculate target point and animation time
            len = sqrt(((current.x - next.position.x) * (current.x - next.position.x)) + ((current.y - next.position.y) * (current.y - next.position.y)));
            time = len * CD8_V;
            CGPoint target;
            target.x = round(next.position.x + (current.x - next.position.x)*1.75*CELL_RADIUS/len);
            target.y = round(next.position.y + (current.y - next.position.y)*1.75*CELL_RADIUS/len);
            // add move to action queue
            [rightActions addObject:[CCMoveTo actionWithDuration:time position:target]];
            if (model.infected){
                // if the cell is infected, induce cell death (without adding to 'killed' count)
                [rightActions addObject:[CCCallBlock actionWithBlock:^{
                                        [self performSelector:@selector(induceCellDeath:) withObject:next afterDelay:.1];
                                    }]];
            }
            // add a short delay to help with flow of the animation
            [rightActions addObject:[CCDelayTime actionWithDuration:.4]];
            // store new future position for use in queuing next move
            current = next.position;
        }
        // cell leaves screen 
        len = sqrt(((current.x - hLCoords.x) * (current.x - hLCoords.x)) + ((current.y - hLCoords.y) * (current.y - hLCoords.y)));
        time = len * CD8_V;
        [rightActions addObject:[CCMoveTo actionWithDuration:time position:hLCoords]];
        
        // play alert sound
        [[SimpleAudioEngine sharedEngine] playEffect:@"Alert.wav"];
        // run action sequences for each respective helper cell
        [hLCell runAction:[CCSequence actionsWithArray:leftActions]];
        [hRCell runAction:[CCSequence actionsWithArray:rightActions]];
        // release action sequence arrays
        [leftActions release];
        [rightActions release];
        
    }
}


// release all retained objects
- (void) dealloc
{
	// cocos2d will automatically release all the children (Label)
	[sprites release];
    [objects release];
    [spriteSheet release];
    [CD8 release];
    [infectedLabel release];
    [totalLabel release];
    [game release];
	// don't forget to call "super dealloc"
	[super dealloc];
}
@end
