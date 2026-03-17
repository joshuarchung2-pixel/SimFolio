# SimFolio - Manual Testing Checklist

## Pre-Testing Setup

- [ ] Clean install on test device
- [ ] Delete any previous app data
- [ ] Ensure device has sample photos
- [ ] Enable VoiceOver for accessibility testing
- [ ] Test on both light and dark mode

---

## 1. Onboarding Flow

### First Launch
- [ ] Onboarding appears on first launch
- [ ] Welcome page displays correctly with "SimFolio" branding
- [ ] Smart Capture features page shows all features
- [ ] Portfolio Tracking page shows all features
- [ ] Skip button works correctly
- [ ] Page indicators update correctly
- [ ] Swipe navigation works between pages
- [ ] Animations are smooth

### Permissions
- [ ] Camera permission request appears
- [ ] Camera permission granted state shows correctly
- [ ] Camera permission denied state shows correctly
- [ ] Photo library permission request appears
- [ ] Full access option works
- [ ] Limited access option works
- [ ] Permission denied state shows correctly
- [ ] Get Started button completes onboarding
- [ ] Main app loads after onboarding

### Subsequent Launches
- [ ] Onboarding does NOT appear on second launch
- [ ] App loads directly to Home tab
- [ ] State is preserved between launches

---

## 2. Home Dashboard

### Layout
- [ ] Welcome message displays correctly
- [ ] Stats cards display accurate values
- [ ] Quick actions section visible
- [ ] Active portfolios section shows portfolios
- [ ] Recent photos section shows photos
- [ ] All sections scroll properly

### Interactions
- [ ] Quick capture button navigates to capture
- [ ] View all portfolios button works
- [ ] Portfolio cards are tappable
- [ ] Portfolio cards show progress rings
- [ ] Recent photos are tappable
- [ ] Pull to refresh works

### Edge Cases
- [ ] Empty state shows when no portfolios
- [ ] Empty state shows when no photos
- [ ] Long portfolio names truncate properly
- [ ] Progress percentages display correctly

---

## 3. Capture Flow

### Camera View
- [ ] Camera preview loads
- [ ] Camera fills screen properly
- [ ] Orientation is handled correctly
- [ ] Camera preview quality is acceptable

### Camera Controls
- [ ] Flash toggle works (auto/on/off)
- [ ] Flash icon updates correctly
- [ ] Grid overlay toggle works
- [ ] Camera switches front/back (if available)
- [ ] Zoom gestures work (if implemented)

### Pre-Capture Tagging
- [ ] Procedure picker opens
- [ ] All procedures display
- [ ] Procedure selection highlights
- [ ] Stage picker appears after procedure
- [ ] Angle picker appears after stage
- [ ] Tooth number picker works
- [ ] Tags display on camera view
- [ ] Clear tags button works

### Capture Action
- [ ] Capture button captures photo
- [ ] Shutter sound plays (if enabled)
- [ ] Haptic feedback fires (if enabled)
- [ ] Preview shows captured image
- [ ] Capture button is large and accessible

### Review Screen
- [ ] Captured photo displays correctly
- [ ] Tags are editable
- [ ] Rating stars work (tap and drag)
- [ ] Notes field accepts input
- [ ] Retake button works
- [ ] Save button saves photo
- [ ] Discard option works with confirmation

### Batch Capture
- [ ] Can capture multiple photos
- [ ] Tags persist between captures
- [ ] Count updates correctly
- [ ] Done saves all photos
- [ ] Navigation returns to appropriate screen

---

## 4. Library

### Grid View
- [ ] Photos display in grid
- [ ] Thumbnails load quickly
- [ ] Scroll performance is smooth (60fps)
- [ ] Pull to refresh works
- [ ] Infinite scroll loads more photos
- [ ] Tag badges display on thumbnails

### Filtering
- [ ] Filter button opens filter sheet
- [ ] Procedure filter works
- [ ] Stage filter works
- [ ] Angle filter works
- [ ] Date range filter works
- [ ] Rating filter works
- [ ] Clear filters works
- [ ] Active filters show indicator/badge
- [ ] Multiple filters combine correctly

### Search
- [ ] Search field accepts input
- [ ] Search filters results in real-time
- [ ] Search is debounced (no lag)
- [ ] Clear search works
- [ ] Empty search results show message

### Photo Detail
- [ ] Photo opens full screen
- [ ] Pinch to zoom works
- [ ] Double tap zooms in/out
- [ ] Pan when zoomed works
- [ ] Swipe between photos works
- [ ] Metadata displays correctly
- [ ] Edit button opens editor
- [ ] Share button works
- [ ] Delete button works with confirmation
- [ ] Dismiss gesture works

### Multi-Select
- [ ] Select mode activates
- [ ] Multiple photos selectable
- [ ] Selection count updates
- [ ] Select all works
- [ ] Bulk delete works with confirmation
- [ ] Bulk tag works
- [ ] Cancel exits select mode
- [ ] Selection persists when scrolling

---

## 5. Portfolios

### Portfolio List
- [ ] Active portfolios section shows
- [ ] Completed portfolios section shows
- [ ] Progress rings display correctly
- [ ] Progress percentages are accurate
- [ ] Due dates display correctly
- [ ] Overdue indicator shows (red styling)
- [ ] Due soon indicator shows
- [ ] Create button works
- [ ] Empty state shows when no portfolios

### Create Portfolio
- [ ] Name field required validation works
- [ ] Due date picker works
- [ ] Due date can be cleared
- [ ] Add requirement button works
- [ ] Procedure selection works
- [ ] Stage multi-select works
- [ ] Angle multi-select works
- [ ] Photos per angle stepper works
- [ ] Summary calculates correctly
- [ ] Create button creates portfolio
- [ ] Cancel button discards changes

### Portfolio Detail
- [ ] Overview tab displays stats
- [ ] Progress ring is accurate
- [ ] Due date displays correctly
- [ ] Quick actions work
- [ ] Checklist tab shows requirements
- [ ] Requirements are expandable
- [ ] Incomplete items show camera button
- [ ] Photos tab shows matching photos
- [ ] Group by options work
- [ ] Edit portfolio works
- [ ] Delete portfolio works with confirmation

### Checklist
- [ ] Requirements expand/collapse
- [ ] Stage sections visible
- [ ] Angle rows show status
- [ ] Thumbnails load for fulfilled items
- [ ] Camera button pre-fills capture
- [ ] Completed items show checkmark
- [ ] Progress updates in real-time

### Export
- [ ] Export button opens sheet
- [ ] Format options work (ZIP/PDF/Individual)
- [ ] Organization options work
- [ ] Quality options work
- [ ] Export generates file
- [ ] Share sheet opens
- [ ] Progress shows during export
- [ ] Cancel export works

---

## 6. Profile & Settings

### Profile Header
- [ ] Avatar displays correctly
- [ ] Default avatar shows when none set
- [ ] User name shows
- [ ] School/institution shows
- [ ] Stats are accurate

### Edit Profile
- [ ] Photo picker works
- [ ] Camera option works (if available)
- [ ] Photo preview shows
- [ ] Remove photo works
- [ ] First name field works
- [ ] Last name field works
- [ ] School picker/field works
- [ ] Class year field works
- [ ] Save updates profile
- [ ] Cancel discards changes

### Procedure Management
- [ ] Procedures list loads
- [ ] Toggle enable/disable works
- [ ] Drag to reorder works
- [ ] Edit procedure works
- [ ] Add custom procedure works
- [ ] Color picker works
- [ ] Delete custom procedure works
- [ ] Cannot delete default procedures
- [ ] Reset to defaults works with confirmation

### Capture Settings
- [ ] Grid lines toggle works
- [ ] Flash default works
- [ ] Haptic feedback toggle works
- [ ] Sound toggle works
- [ ] Pre-capture tagging toggle works
- [ ] Remember tags toggle works
- [ ] Auto-save toggle works
- [ ] Image quality setting works

### Notifications
- [ ] Permission status shows correctly
- [ ] Enable notifications works
- [ ] Due date reminders toggle works
- [ ] Reminder timing setting works
- [ ] Weekly progress toggle works
- [ ] Reminder time picker works

### Data Management
- [ ] Storage info displays correctly
- [ ] Export data works
- [ ] Clear tags works with confirmation
- [ ] Clear all works with confirmation
- [ ] Warnings display appropriately

### About
- [ ] Version displays correctly
- [ ] Build number displays
- [ ] Features list shows
- [ ] Links open correctly
- [ ] Rate app works (if implemented)
- [ ] Share app works

---

## 7. Accessibility

### VoiceOver
- [ ] All buttons have labels
- [ ] Images have descriptions
- [ ] Navigation order is logical
- [ ] Headers are marked correctly
- [ ] Progress values are announced
- [ ] Adjustable controls work
- [ ] Custom actions appear in rotor
- [ ] Forms are navigable
- [ ] Alerts are announced

### Dynamic Type
- [ ] Text scales with system setting
- [ ] Layout adapts at large sizes
- [ ] No text truncation at accessibility sizes
- [ ] Buttons remain tappable
- [ ] Touch targets stay >= 44pt

### Reduce Motion
- [ ] Animations respect setting
- [ ] Transitions are instant or cross-fade
- [ ] No parallax effects
- [ ] Progress rings don't animate

### Color & Contrast
- [ ] Text is readable in light mode
- [ ] Text is readable in dark mode
- [ ] Controls have sufficient contrast
- [ ] Color is not only indicator
- [ ] Focus indicators are visible

---

## 8. Performance

### Launch
- [ ] App launches in < 2 seconds
- [ ] Home content loads quickly
- [ ] No loading flicker
- [ ] No white flash

### Scrolling
- [ ] Library grid scrolls smoothly (60fps)
- [ ] Portfolio list scrolls smoothly
- [ ] No stuttering during prefetch
- [ ] Images load progressively

### Camera
- [ ] Camera initializes quickly
- [ ] Preview is responsive
- [ ] Capture is instant
- [ ] No lag in controls

### Memory
- [ ] Memory stays below 200MB typical
- [ ] No crashes on memory warning
- [ ] Caches clear appropriately
- [ ] Background memory is minimal

### Battery
- [ ] Camera doesn't drain excessively
- [ ] Background tasks complete properly
- [ ] No excessive CPU usage when idle

---

## 9. Edge Cases

### Error Handling
- [ ] No camera permission shows clear error
- [ ] No photo permission shows clear error
- [ ] Empty states display correctly
- [ ] Network errors handled (if applicable)
- [ ] Corrupted data handled gracefully

### Data Persistence
- [ ] Data survives app kill
- [ ] Data survives device restart
- [ ] Data survives app update
- [ ] Settings persist correctly

### Input Validation
- [ ] Empty names rejected
- [ ] Invalid dates handled
- [ ] Very long text handled
- [ ] Special characters work

### Interruptions
- [ ] Phone call during capture handled
- [ ] App backgrounding during capture handled
- [ ] Low battery during export handled
- [ ] Notification during use doesn't crash

---

## 10. Device Compatibility

### Screen Sizes
- [ ] Works on iPhone SE (small screen)
- [ ] Works on iPhone 15 (standard)
- [ ] Works on iPhone 15 Pro Max (large screen)
- [ ] Works on iPad (if supported)
- [ ] Landscape orientation (if supported)

### iOS Versions
- [ ] Works on iOS 16 (if supported)
- [ ] Works on iOS 17
- [ ] Works on iOS 18

### Hardware
- [ ] Works on devices with notch
- [ ] Works on devices with Dynamic Island
- [ ] Works on devices without Face ID
- [ ] Camera features work on older devices

---

## 11. Regression Testing

After each update, verify:
- [ ] Existing portfolios still display
- [ ] Photo metadata preserved
- [ ] Settings preserved
- [ ] User profile preserved
- [ ] No new crashes
- [ ] Performance not degraded
- [ ] All previous fixes still work

---

## Test Results Summary

| Section | Pass | Fail | Skip | Notes |
|---------|------|------|------|-------|
| Onboarding | | | | |
| Home Dashboard | | | | |
| Capture Flow | | | | |
| Library | | | | |
| Portfolios | | | | |
| Profile & Settings | | | | |
| Accessibility | | | | |
| Performance | | | | |
| Edge Cases | | | | |
| Device Compatibility | | | | |
| Regression | | | | |

---

## Issues Found

| # | Section | Description | Severity | Status |
|---|---------|-------------|----------|--------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |

**Severity Levels:** Critical, High, Medium, Low, Cosmetic

---

## Testing Environment

- **Device:**
- **iOS Version:**
- **App Version:**
- **Date:**
- **Tester:**

---

## Notes

Add any additional notes, observations, or recommendations here.
