//
//  ImageTableViewController.m
//  RealEstateViewer
//
//  Created by Johannes Fahrenkrug on 07.10.10.
//  Copyright 2010 Springenwerk. All rights reserved.
//

#import "ImageTableViewController.h"
#import "JSON.h"

@implementation ImageTableViewController
@synthesize results;

#pragma mark -
#pragma mark Initialization

- (id)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
		results = [NSArray array];
		
		UISearchBar *searchBar = [[UISearchBar alloc] 
			initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 0)];  
		searchBar.delegate = self;  
		searchBar.showsCancelButton = YES;   
		[searchBar sizeToFit];  
		
		self.tableView.tableHeaderView = searchBar;  
		[searchBar release];  
		
		self.tableView.rowHeight = 160;
    }
    return self;
}

#pragma mark -
#pragma mark UISearchBarDelegate methods

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	NSLog(@"Searching for: %@", searchBar.text);
	NSString *api = @"http://ajax.googleapis.com/ajax/services/search/images?v=1.0&rsz=large&imgtype=photo&q=";
	NSString *urlString = [NSString stringWithFormat:@"%@real%%20estate%%20%@", api, 
			[searchBar.text stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	NSURL *url = [NSURL URLWithString:urlString];
	
	// get the global default priority queue
	dispatch_queue_t defQueue = 
		dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	// declare our block
	void (^imageAPIBlock) (void);

	imageAPIBlock = ^{
		// sleep for 1.5 seconds to fake network lag
		[NSThread sleepForTimeInterval:1.5];
	
		NSData *data = [NSData dataWithContentsOfURL:url];
		
		NSString *res = [[NSString alloc] initWithData:data 
											  encoding:NSUTF8StringEncoding];
		
		// Parse the results
		NSArray *newResults = [[[res JSONValue] objectForKey:@"responseData"] 
						objectForKey:@"results"];
		
		[res release];
		
		// call back to the main thread
		dispatch_async(dispatch_get_main_queue(), ^{
			self.results = newResults;
			[self.tableView reloadData];
		});
	};
	
	// dispatch the imageAPI block...
	dispatch_async(defQueue, imageAPIBlock);
	
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar {
	[searchBar resignFirstResponder];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView 
 numberOfRowsInSection:(NSInteger)section {
    return [results count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView 
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView 
							 dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault 
									   reuseIdentifier:CellIdentifier] autorelease];
    } else {
		// remove old spinner & image view
		for (UIView *view in cell.contentView.subviews) {
			[view removeFromSuperview];
		}
	}
    
    // Try to get cached image...
	// We use the __block storage type so we can 
	// set it from inside our block
	__block UIImage *image = [[results objectAtIndex:indexPath.row] objectForKey:@"image"];
	
	if (!image) {
		// declare our image loading block
		void (^imageLoadingBlock) (void);
		
		// create and set up a loading spinner
		UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
											 initWithActivityIndicatorStyle:
											UIActivityIndicatorViewStyleGray];
		
		spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | 
								   UIViewAutoresizingFlexibleRightMargin | 
								   UIViewAutoresizingFlexibleTopMargin | 
								   UIViewAutoresizingFlexibleBottomMargin;
		
		spinner.contentMode = UIViewContentModeCenter;
		spinner.center = cell.contentView.center;
		[spinner startAnimating];
		
		[cell.contentView addSubview:spinner];
		[spinner release];
		
		imageLoadingBlock = ^{
			// fetch the image from the internet
			image = [UIImage imageWithData:
					 [NSData dataWithContentsOfURL:
					  [NSURL URLWithString:[[results objectAtIndex:indexPath.row] 
											objectForKey:@"unescapedUrl"]]]];
			
			// we need to retain it because it's a __block 
			// variable which won't be auto-retained in a block
			[image retain];
			
			// call back to the main thread
			dispatch_async(dispatch_get_main_queue(), ^{
				// Safely cache the image
				[[results objectAtIndex:indexPath.row] setValue:image 
														 forKey:@"image"];
				
				[image release];
				[spinner stopAnimating];
				
				// reload the affected row
				[self.tableView reloadRowsAtIndexPaths:
					[NSArray arrayWithObject:indexPath] withRowAnimation:NO];
			});
			
		};
		
		// dispatch our image loading block to the 
		// default priority queue
		dispatch_async(dispatch_get_global_queue(
						DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), 
					   imageLoadingBlock);
		
	} else {
		// we've got the cached image, so we can use it
		UIImageView *imageView = [[[UIImageView alloc] initWithImage:image] 
								  autorelease];
		
		imageView.contentMode = UIViewContentModeScaleAspectFit;
		imageView.autoresizingMask =  UIViewAutoresizingFlexibleWidth | 
									  UIViewAutoresizingFlexibleHeight;
		imageView.frame = cell.contentView.frame;
		
		[cell.contentView addSubview:imageView];
	}
    
    return cell;
}

#pragma mark -
#pragma mark Memory management

- (void)dealloc {
	[results release];
    [super dealloc];
}

@end

