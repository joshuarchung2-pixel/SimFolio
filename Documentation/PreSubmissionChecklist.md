# Pre-Submission Checklist

Complete this checklist before submitting SimFolio to the App Store.

---

## Code Quality

- [ ] All compiler warnings resolved
- [ ] No force unwraps (`!`) in production code (except IBOutlets)
- [ ] All TODO/FIXME comments addressed or documented
- [ ] Code reviewed and cleaned up
- [ ] Debug code removed (print statements, test data)
- [ ] No hardcoded test credentials or URLs
- [ ] API keys secured (if applicable)
- [ ] Unused code and files removed
- [ ] No commented-out code blocks

## Testing

- [ ] All unit tests pass
- [ ] All UI tests pass
- [ ] Manual testing complete on multiple devices
- [ ] Edge cases tested (empty states, errors, etc.)
- [ ] Memory leaks checked with Instruments
- [ ] Performance profiled with Instruments
- [ ] Tested on oldest supported iOS version
- [ ] Tested on latest iOS version
- [ ] Tested fresh install experience
- [ ] Tested upgrade from previous version (if applicable)

## Assets

- [ ] App icon set complete (all required sizes)
- [ ] Launch screen configured and displaying correctly
- [ ] All images are @2x and @3x
- [ ] No placeholder images remaining
- [ ] Image file sizes optimized
- [ ] Vector assets used where appropriate

## Configuration

- [ ] Bundle ID is correct and final
- [ ] Version number updated (CFBundleShortVersionString)
- [ ] Build number incremented (CFBundleVersion)
- [ ] Signing configured for distribution
- [ ] Info.plist complete with all required keys
- [ ] Deployment target is correct
- [ ] Supported devices are correct

## Privacy & Permissions

- [ ] All permission descriptions are clear and accurate
- [ ] Camera usage description explains purpose
- [ ] Photo library usage description explains purpose
- [ ] Privacy policy is published and accessible
- [ ] No unnecessary permissions requested
- [ ] App Tracking Transparency (if applicable)

## App Store Connect

### App Information
- [ ] App record created
- [ ] Bundle ID matches Xcode project
- [ ] Primary language set
- [ ] Category selected (Medical, Productivity)

### Pricing & Availability
- [ ] Pricing tier selected
- [ ] Availability regions selected
- [ ] Release date configured (manual/automatic)

### App Store Listing
- [ ] App name (30 characters max)
- [ ] Subtitle (30 characters max)
- [ ] Keywords (100 characters max)
- [ ] Description (4000 characters max)
- [ ] What's New text (for updates)
- [ ] Support URL provided
- [ ] Marketing URL provided (optional)
- [ ] Privacy Policy URL provided

### Media
- [ ] Screenshots uploaded for all required sizes
  - [ ] iPhone 6.7" (1290 x 2796)
  - [ ] iPhone 6.5" (1242 x 2688)
  - [ ] iPhone 5.5" (1242 x 2208) - optional
- [ ] App preview video (optional)
- [ ] Screenshots show key features
- [ ] Screenshots have captions (optional)

### Age Rating
- [ ] Age rating questionnaire completed
- [ ] Rating matches app content (likely 4+)

### Review Information
- [ ] Contact information provided
- [ ] Review notes written
- [ ] Demo account (if login required) - N/A for SimFolio

## Legal

- [ ] Terms of service (if applicable)
- [ ] Copyright notices correct
- [ ] Third-party licenses documented
- [ ] EULA (if using custom)
- [ ] Export compliance information

## Build & Upload

### Archive
- [ ] Clean build folder before archiving
- [ ] Archive created successfully
- [ ] dSYM files generated
- [ ] Archive validated in Xcode

### Upload
- [ ] Build uploaded to App Store Connect
- [ ] Upload completed without errors
- [ ] Build appears in App Store Connect
- [ ] Build passes automated processing

### TestFlight (Recommended)
- [ ] Internal testing completed
- [ ] External testing completed (if applicable)
- [ ] All feedback addressed
- [ ] Final build verified on TestFlight

## Final Verification

### Functionality
- [ ] Onboarding works correctly
- [ ] Camera capture works
- [ ] Photo library access works
- [ ] Portfolio creation works
- [ ] Export functionality works
- [ ] All navigation paths tested
- [ ] All buttons and actions work

### Edge Cases
- [ ] App handles no photos gracefully
- [ ] App handles no portfolios gracefully
- [ ] App handles denied permissions
- [ ] App handles low storage
- [ ] App handles interruptions (calls, notifications)

### Device Testing
- [ ] Tested on physical device (not just simulator)
- [ ] Tested airplane mode/no network
- [ ] Tested with app in background
- [ ] Tested after device restart

## Submission

- [ ] Select build for submission
- [ ] Answer export compliance questions
- [ ] Answer advertising identifier questions
- [ ] Answer content rights questions
- [ ] Submit for review

---

## Post-Submission

- [ ] Monitor review status daily
- [ ] Prepare to respond to reviewer questions quickly
- [ ] Have fixes ready for common rejection reasons
- [ ] Plan marketing for launch
- [ ] Prepare social media announcements
- [ ] Notify beta testers of upcoming release
- [ ] Set up app analytics (if applicable)

---

## Common Rejection Reasons to Avoid

1. **Crashes and Bugs** - Test thoroughly on multiple devices
2. **Broken Links** - Verify all URLs work
3. **Placeholder Content** - Remove all test data
4. **Incomplete Information** - Fill out all metadata
5. **Misleading Description** - Match description to actual features
6. **Permission Issues** - Justify all requested permissions
7. **Privacy Violations** - Have clear privacy policy
8. **Performance Issues** - Ensure app is responsive

---

## Sign-Off

**Prepared By:** _______________
**Date:** _______________
**Version:** _______________
**Build:** _______________

### Final Notes:
