#import "MWMPlacePageEntity.h"
#import "MWMPlacePageViewManager.h"
#import "MapViewController.h"

#include "Framework.h"
#include "indexer/editable_feature.hpp"
#include "platform/measurement_utils.hpp"

using feature::Metadata;

extern NSString * const kUserDefaultsLatLonAsDMSKey = @"UserDefaultsLatLonAsDMS";
extern NSString * const kMWMCuisineSeparator = @" • ";

namespace
{

NSString * const kOSMCuisineSeparator = @";";

//TODO(Alex): If we can format cuisines in subtitle we won't need this function.

//NSString * makeOSMCuisineString(NSSet<NSString *> * cuisines)
//{
//  NSMutableArray<NSString *> * osmCuisines = [NSMutableArray arrayWithCapacity:cuisines.count];
//  for (NSString * cuisine in cuisines)
//    [osmCuisines addObject:cuisine];
//  [osmCuisines sortUsingComparator:^NSComparisonResult(NSString * s1, NSString * s2)
//  {
//    return [s1 compare:s2];
//  }];
//  return [osmCuisines componentsJoinedByString:kOSMCuisineSeparator];
//}

NSUInteger gMetaFieldsMap[MWMPlacePageCellTypeCount] = {};

void putFields(NSUInteger eTypeValue, NSUInteger ppValue)
{
  gMetaFieldsMap[eTypeValue] = ppValue;
  gMetaFieldsMap[ppValue] = eTypeValue;
}

void initFieldsMap()
{
  putFields(Metadata::FMD_URL, MWMPlacePageCellTypeURL);
  putFields(Metadata::FMD_WEBSITE, MWMPlacePageCellTypeWebsite);
  putFields(Metadata::FMD_PHONE_NUMBER, MWMPlacePageCellTypePhoneNumber);
  putFields(Metadata::FMD_OPEN_HOURS, MWMPlacePageCellTypeOpenHours);
  putFields(Metadata::FMD_EMAIL, MWMPlacePageCellTypeEmail);
  putFields(Metadata::FMD_POSTCODE, MWMPlacePageCellTypePostcode);
  putFields(Metadata::FMD_INTERNET, MWMPlacePageCellTypeWiFi);
  putFields(Metadata::FMD_CUISINE, MWMPlacePageCellTypeCuisine);

  ASSERT_EQUAL(gMetaFieldsMap[Metadata::FMD_URL], MWMPlacePageCellTypeURL, ());
  ASSERT_EQUAL(gMetaFieldsMap[MWMPlacePageCellTypeURL], Metadata::FMD_URL, ());
  ASSERT_EQUAL(gMetaFieldsMap[Metadata::FMD_WEBSITE], MWMPlacePageCellTypeWebsite, ());
  ASSERT_EQUAL(gMetaFieldsMap[MWMPlacePageCellTypeWebsite], Metadata::FMD_WEBSITE, ());
  ASSERT_EQUAL(gMetaFieldsMap[Metadata::FMD_POSTCODE], MWMPlacePageCellTypePostcode, ());
  ASSERT_EQUAL(gMetaFieldsMap[MWMPlacePageCellTypePostcode], Metadata::FMD_POSTCODE, ());
  ASSERT_EQUAL(gMetaFieldsMap[Metadata::FMD_MAXSPEED], 0, ());
}
} // namespace

@interface MWMPlacePageEntity ()

@property (nonatomic, readwrite) BOOL canEditObject;

@end

@implementation MWMPlacePageEntity
{
  set<MWMPlacePageCellType> m_editableFields;
  MWMPlacePageCellTypeValueMap m_values;
  place_page::Info m_info;
}

+ (NSString *)makeMWMCuisineString:(NSSet<NSString *> *)cuisines
{
  NSString * prefix = @"cuisine_";
  NSMutableArray<NSString *> * localizedCuisines = [NSMutableArray arrayWithCapacity:cuisines.count];
  for (NSString * cus in cuisines)
  {
    NSString * cuisine = [prefix stringByAppendingString:cus];
    NSString * localizedCuisine = L(cuisine);
    BOOL const noLocalization = [localizedCuisine isEqualToString:cuisine];
    [localizedCuisines addObject:noLocalization ? cus : localizedCuisine];
  }
  [localizedCuisines sortUsingComparator:^NSComparisonResult(NSString * s1, NSString * s2)
  {
    return [s1 compare:s2 options:NSCaseInsensitiveSearch range:{0, s1.length} locale:[NSLocale currentLocale]];
  }];
  return [localizedCuisines componentsJoinedByString:kMWMCuisineSeparator];
}

- (instancetype)initWithInfo:(const place_page::Info &)info
{
  self = [super init];
  if (self)
  {
    m_info = info;
    initFieldsMap();
    [self config];
  }
  return self;
}

- (void)config
{
  if (m_info.IsFeature())
    [self configureWithFeature];

  if (m_info.IsMyPosition())
    [self configureForMyPosition];

  if (m_info.HasApiUrl())
    [self configureForApi];

  if (m_info.IsBookmark())
    [self configureForBookmark];

  [self setEditableTypes];
}

- (void)setMetaField:(NSUInteger)key value:(string const &)value
{
  NSAssert(key >= Metadata::FMD_COUNT, @"Incorrect enum value");
  MWMPlacePageCellType const cellType = static_cast<MWMPlacePageCellType>(key);
  if (value.empty())
    m_values.erase(cellType);
  else
    m_values[cellType] = value;
}

- (void)configureForBookmark
{
  BookmarkCategory * cat = GetFramework().GetBmCategory(m_info.m_bac.first);
  BookmarkData const & data = static_cast<Bookmark const *>(cat->GetUserMark(m_info.m_bac.second))->GetData();

  self.bookmarkTitle = @(data.GetName().c_str());
  self.bookmarkCategory = @(cat->GetName().c_str());
  string const & description = data.GetDescription();
  self.bookmarkDescription = @(description.c_str());
  _isHTMLDescription = strings::IsHTML(description);
  self.bookmarkColor = @(data.GetType().c_str());
}

- (void)configureForMyPosition
{
  // TODO: Refactor these configure* methods.
//  self.title = @(m_info.GetTitle().c_str());//L(@"my_position");
}

- (void)configureForApi
{
//  self.title = @(m_info.GetTitle().c_str());
  self.category = @(GetFramework().GetApiDataHolder().GetAppTitle().c_str());
}

- (void)configureWithFeature
{
  search::AddressInfo const address = GetFramework().GetAddressInfoAtPoint(m_info.GetMercator());
  self.title = @(m_info.GetTitle().c_str());
  // TODO: Review subtitle logic. It's better to create it in info in C++.
  NSMutableArray * subtitle = [@[] mutableCopy];
  if (!m_info.GetSubtitle().empty())
    [subtitle addObject:@(m_info.GetSubtitle().c_str())];
  self.address = @(address.FormatAddress().c_str());

  // TODO(AlexZ): Do we need this house logic?
  if (!address.m_house.empty())
    [self setMetaField:MWMPlacePageCellTypeBuilding value:address.m_house];

  feature::Metadata const & md = m_info.GetMetadata();
  for (auto const type : md.GetPresentTypes())
  {
    switch (type)
    {
//    case Metadata::FMD_CUISINE:
//      {
//        [self deserializeCuisine:@(md.Get(type).c_str())];
//        NSString * cuisine = [self getCellValue:MWMPlacePageCellTypeCuisine];
//        if (self.category.length == 0)
//          self.category = cuisine;
//        else if (![self.category isEqualToString:cuisine])
//          self.category = [NSString stringWithFormat:@"%@%@%@", self.category, kMWMCuisineSeparator, cuisine];
//        break;
//      }
//      case Metadata::FMD_ELE:
//      {
//        self.typeDescriptionValue = atoi(metadata.Get(type).c_str());
//        if (self.type != MWMPlacePageEntityTypeBookmark)
//          self.type = MWMPlacePageEntityTypeEle;
//        break;
//      }
//      case Metadata::FMD_OPERATOR:
//      {
//        NSString * bank = @(metadata.Get(type).c_str());
//        if (self.category.length)
//          self.category = [NSString stringWithFormat:@"%@%@%@", self.category, kMWMCuisineSeparator, bank];
//        else
//          self.category = bank;
//        break;
//      }
//      case Metadata::FMD_STARS:
//      {
//        self.typeDescriptionValue = atoi(metadata.Get(type).c_str());
//        if (self.type != MWMPlacePageEntityTypeBookmark)
//          self.type = MWMPlacePageEntityTypeHotel;
//        break;
//      }
      case Metadata::FMD_URL:
      case Metadata::FMD_WEBSITE:
      case Metadata::FMD_PHONE_NUMBER:
      case Metadata::FMD_OPEN_HOURS:
      case Metadata::FMD_EMAIL:
      case Metadata::FMD_POSTCODE:
        [self setMetaField:gMetaFieldsMap[type] value:md.Get(type)];
        break;
      case Metadata::FMD_INTERNET:
        [self setMetaField:gMetaFieldsMap[type] value:L(@"WiFi_available").UTF8String];
        break;
      default:
        break;
    }
  }

  [self processStreets];
}

- (void)toggleCoordinateSystem
{
  NSUserDefaults * ud = [NSUserDefaults standardUserDefaults];
  [ud setBool:![ud boolForKey:kUserDefaultsLatLonAsDMSKey] forKey:kUserDefaultsLatLonAsDMSKey];
  [ud synchronize];
}

- (void)deserializeCuisine:(NSString *)cuisine
{
  self.cuisines = [NSSet setWithArray:[cuisine componentsSeparatedByString:kOSMCuisineSeparator]];
}

- (void)processStreets
{
  Framework & frm = GetFramework();
  auto const streets = frm.GetNearbyFeatureStreets(m_info.m_featureID);
  NSMutableArray * arr = [[NSMutableArray alloc] initWithCapacity:streets.size()];
  for (auto const & street : streets)
    [arr addObject:@(street.c_str())];
  self.nearbyStreets = arr;

  auto const info = frm.GetFeatureAddressInfo(m_info.m_featureID);
  [self setMetaField:MWMPlacePageCellTypeStreet value:info.m_street];
}

#pragma mark - Editing

- (void)setEditableTypes
{
  // TODO(AlexZ): Refactor editor interface to accept FeatureID.
  auto const feature = GetFramework().GetFeatureByID(m_info.m_featureID);
  auto const editable = osm::Editor::Instance().GetEditableProperties(*feature);
  self.canEditObject = editable.IsEditable();
  if (editable.m_name)
    m_editableFields.insert(MWMPlacePageCellTypeName);
  if (editable.m_address)
  {
    m_editableFields.insert(MWMPlacePageCellTypeStreet);
    m_editableFields.insert(MWMPlacePageCellTypeBuilding);
  }
  for (feature::Metadata::EType const type : editable.m_metadata)
  {
    NSAssert(gMetaFieldsMap[type] >= Metadata::FMD_COUNT || gMetaFieldsMap[type] == 0, @"Incorrect enum value");
    MWMPlacePageCellType const field = static_cast<MWMPlacePageCellType>(gMetaFieldsMap[type]);
    m_editableFields.insert(field);
  }
}

- (BOOL)isCellEditable:(MWMPlacePageCellType)cellType
{
  return m_editableFields.count(cellType) == 1;
}

- (void)saveEditing:(osm::EditableFeature const &)feature
{

}

- (void)saveEditedCells:(MWMPlacePageCellTypeValueMap const &)cells
{
  // TODO(Vlad): Before editing starts, we should get editable feature first using code below:
  // osm::EditableFeature ef;
  // GetFramework().GetEditableFeature(self.delegate.info.m_featureID, ef);
  //
  // TODO(Vlad): After that, ef structure should be filled by information from user.
  //
  // TODO(Vlad): When editing finishes, this code should be called:
  // GetFramework().SaveEditedFeature(ef);
  
//  auto & metadata = feature->GetMetadata();
//  NSString * entityStreet = [self getCellValue:MWMPlacePageCellTypeStreet];
//  string streetName = (entityStreet ? entityStreet : @"").UTF8String;
//  NSString * entityHouseNumber = [self getCellValue:MWMPlacePageCellTypeBuilding];
//  string houseNumber = (entityHouseNumber ? entityHouseNumber : @"").UTF8String;;
//  for (auto const & cell : cells)
//  {
//    switch (cell.first)
//    {
//      case MWMPlacePageCellTypePhoneNumber:
//      case MWMPlacePageCellTypeWebsite:
//      case MWMPlacePageCellTypeOpenHours:
//      case MWMPlacePageCellTypeEmail:
//      case MWMPlacePageCellTypeWiFi:
//      {
//        Metadata::EType const fmdType = static_cast<Metadata::EType>(gMetaFieldsMap[cell.first]);
//        NSAssert(fmdType > 0 && fmdType < Metadata::FMD_COUNT, @"Incorrect enum value");
//        metadata.Set(fmdType, cell.second);
//        break;
//      }
//      case MWMPlacePageCellTypeCuisine:
//      {
//        Metadata::EType const fmdType = static_cast<Metadata::EType>(gMetaFieldsMap[cell.first]);
//        NSAssert(fmdType > 0 && fmdType < Metadata::FMD_COUNT, @"Incorrect enum value");
//        NSString * osmCuisineStr = makeOSMCuisineString(self.cuisines);
//        metadata.Set(fmdType, osmCuisineStr.UTF8String);
//        break;
//      }
//      case MWMPlacePageCellTypeName:
//      {
//        // TODO(AlexZ): Make sure that we display and save name in the same language (default?).
//        auto names = feature->GetNames();
//        names.AddString(StringUtf8Multilang::kDefaultCode, cell.second);
//        feature->SetNames(names);
//        break;
//      }
//      case MWMPlacePageCellTypeStreet:
//      {
//        streetName = cell.second;
//        break;
//      }
//      case MWMPlacePageCellTypeBuilding:
//      {
//        houseNumber = cell.second;
//        break;
//      }
//      default:
//        NSAssert(false, @"Invalid field for editor");
//        break;
//    }
//  }
//  osm::Editor::Instance().EditFeature(*feature, streetName, houseNumber);
}

#pragma mark - Getters

- (NSString *)getCellValue:(MWMPlacePageCellType)cellType
{
  switch (cellType)
  {
    case MWMPlacePageCellTypeName:
      return self.title;
    case MWMPlacePageCellTypeCoordinate:
      return [self coordinate];
    case MWMPlacePageCellTypeBookmark:
      return m_info.IsBookmark() ? @"haveValue" : nil;
    case MWMPlacePageCellTypeEditButton:
      return self.canEditObject ? @"haveValue" : nil;
    default:
    {
      auto const it = m_values.find(cellType);
      BOOL const haveField = (it != m_values.end());
      return haveField ? @(it->second.c_str()) : nil;
    }
  }
}

- (BOOL)isMyPosition
{
  return m_info.IsMyPosition();
}

- (BOOL)isBookmark
{
  return m_info.IsBookmark();
}

- (BOOL)isApi
{
  return m_info.HasApiUrl();
}

- (ms::LatLon)latlon
{
  return m_info.GetLatLon();
}

- (m2::PointD const &)mercator
{
  return m_info.GetMercator();
}

- (NSString *)apiURL
{
  return @(m_info.GetApiUrl().c_str());
}

- (NSString *)coordinate
{
  BOOL const useDMSFormat =
      [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultsLatLonAsDMSKey];
  ms::LatLon const latlon = self.latlon;
  return @((useDMSFormat ? MeasurementUtils::FormatLatLon(latlon.lat, latlon.lon)
                         : MeasurementUtils::FormatLatLonAsDMS(latlon.lat, latlon.lon, 2)).c_str());
}

#pragma mark - Properties

@synthesize cuisines = _cuisines;
- (NSSet<NSString *> *)cuisines
{
  if (!_cuisines)
    _cuisines = [NSSet set];
  return _cuisines;
}

- (void)setCuisines:(NSSet<NSString *> *)cuisines
{
  if ([_cuisines isEqualToSet:cuisines])
    return;
  _cuisines = cuisines;
  [self setMetaField:MWMPlacePageCellTypeCuisine
               value:[MWMPlacePageEntity makeMWMCuisineString:cuisines].UTF8String];
}

#pragma mark - Bookmark editing

- (void)setBac:(BookmarkAndCategory)bac
{
  m_info.m_bac = bac;
}

- (BookmarkAndCategory)bac
{
  return m_info.m_bac;
}

- (NSString *)bookmarkCategory
{
  if (!_bookmarkCategory)
  {
    Framework & f = GetFramework();
    BookmarkCategory * category = f.GetBmCategory(f.LastEditedBMCategory());
    _bookmarkCategory = @(category->GetName().c_str());
  }
  return _bookmarkCategory;
}

- (NSString *)bookmarkDescription
{
  if (!_bookmarkDescription)
    _bookmarkDescription = @"";
  return _bookmarkDescription;
}

- (NSString *)bookmarkColor
{
  if (!_bookmarkColor)
  {
    Framework & f = GetFramework();
    string type = f.LastEditedBMType();
    _bookmarkColor = @(type.c_str());
  }
  return _bookmarkColor;
}

- (NSString *)bookmarkTitle
{
  if (!_bookmarkTitle)
    _bookmarkTitle = self.title;
  return _bookmarkTitle;
}

- (void)synchronize
{
  Framework & f = GetFramework();
  BookmarkCategory * category = f.GetBmCategory(self.bac.first);
  if (!category)
    return;

  {
    BookmarkCategory::Guard guard(*category);
    Bookmark * bookmark = static_cast<Bookmark *>(guard.m_controller.GetUserMarkForEdit(self.bac.second));
    if (!bookmark)
      return;
  
    if (self.bookmarkColor)
      bookmark->SetType(self.bookmarkColor.UTF8String);

    if (self.bookmarkDescription)
    {
      string const description(self.bookmarkDescription.UTF8String);
      _isHTMLDescription = strings::IsHTML(description);
      bookmark->SetDescription(description);
    }

    if (self.bookmarkTitle)
      bookmark->SetName(self.bookmarkTitle.UTF8String);
  }
  
  category->SaveToKMLFile();
}

@end
