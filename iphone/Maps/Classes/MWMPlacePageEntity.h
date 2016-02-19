#include "Framework.h"

#include "map/user_mark.hpp"
#include "indexer/feature_meta.hpp"

typedef NS_ENUM(NSUInteger, MWMPlacePageCellType)
{
  MWMPlacePageCellTypePostcode = feature::Metadata::EType::FMD_COUNT,
  MWMPlacePageCellTypePhoneNumber,
  MWMPlacePageCellTypeWebsite,
  MWMPlacePageCellTypeURL,
  MWMPlacePageCellTypeEmail,
  MWMPlacePageCellTypeOpenHours,
  MWMPlacePageCellTypeWiFi,
  MWMPlacePageCellTypeCoordinate,
  MWMPlacePageCellTypeBookmark,
  MWMPlacePageCellTypeEditButton,
  MWMPlacePageCellTypeName,
  MWMPlacePageCellTypeStreet,
  MWMPlacePageCellTypeBuilding,
  MWMPlacePageCellTypeCuisine,
  MWMPlacePageCellTypeCount
};

using MWMPlacePageCellTypeValueMap = map<MWMPlacePageCellType, string>;

@class MWMPlacePageViewManager;

@interface MWMPlacePageEntity : NSObject

+ (NSString *)makeMWMCuisineString:(NSSet<NSString *> *)cuisines;

@property (copy, nonatomic) NSString * title;
@property (copy, nonatomic) NSString * category;
@property (copy, nonatomic) NSString * address;
@property (copy, nonatomic) NSString * bookmarkTitle;
@property (copy, nonatomic) NSString * bookmarkCategory;
@property (copy, nonatomic) NSString * bookmarkDescription;
@property (nonatomic, readonly) BOOL isHTMLDescription;
@property (copy, nonatomic) NSString * bookmarkColor;
@property (copy, nonatomic) NSSet<NSString *> * cuisines;
@property (copy, nonatomic) NSArray<NSString *> * nearbyStreets;
@property (nonatomic, readonly) BOOL canEditObject;

@property (nonatomic) int typeDescriptionValue;

@property (nonatomic) BookmarkAndCategory bac;
@property (weak, nonatomic) MWMPlacePageViewManager * manager;

- (BOOL)isMyPosition;
- (BOOL)isBookmark;
- (BOOL)isApi;
- (ms::LatLon)latlon;
- (m2::PointD const &)mercator;
- (NSString *)apiURL;

- (instancetype)initWithInfo:(place_page::Info const &)info;
- (void)synchronize;

- (void)toggleCoordinateSystem;

- (NSString *)getCellValue:(MWMPlacePageCellType)cellType;
- (BOOL)isCellEditable:(MWMPlacePageCellType)cellType;
- (void)saveEditedCells:(MWMPlacePageCellTypeValueMap const &)cells;

@end
