# UI Polish Checklist

Use this checklist before submitting SimFolio to the App Store.

## Typography

- [ ] All text uses design system fonts (AppTheme.Typography)
- [ ] Font sizes are consistent across similar elements
- [ ] Line heights are appropriate for readability
- [ ] Text is readable at all supported Dynamic Type sizes
- [ ] No text is clipped or truncated unexpectedly
- [ ] Placeholder text is styled appropriately

## Colors

- [ ] Colors match design system (AppTheme.Colors)
- [ ] Sufficient contrast ratios (4.5:1 minimum for text)
- [ ] Dark mode colors are correct and legible
- [ ] Light mode colors are correct and legible
- [ ] Accent colors are consistent throughout
- [ ] Error/warning/success colors are distinct
- [ ] Disabled states are visually clear

## Spacing

- [ ] Consistent padding throughout (using AppTheme.Spacing)
- [ ] Margins match design system specifications
- [ ] No overlapping elements
- [ ] Safe areas are properly respected
- [ ] Keyboard avoidance works correctly
- [ ] Content doesn't extend under notch/Dynamic Island
- [ ] Home indicator area is respected

## Icons

- [ ] All icons are SF Symbols or properly sized custom assets
- [ ] Icons have consistent weights and sizes
- [ ] Icons are appropriately sized for touch targets
- [ ] Icons have proper accessibility labels
- [ ] Icon colors match surrounding text/theme
- [ ] Selected/active states are visually distinct

## Animations

- [ ] Animations are smooth (60fps, no jank)
- [ ] Animation durations are consistent (using standard timing)
- [ ] Reduce Motion preference is respected
- [ ] No jarring or unexpected transitions
- [ ] Loading spinners animate correctly
- [ ] Progress indicators update smoothly
- [ ] Tab transitions are fluid

## Loading States

- [ ] Loading indicators appear for async operations
- [ ] Skeleton views for content loading (where appropriate)
- [ ] Progress indicators for long operations
- [ ] No blank screens during loading
- [ ] Loading states don't flash too quickly
- [ ] Cancellation is possible for long operations

## Error States

- [ ] Error messages are user-friendly and actionable
- [ ] Recovery actions are clearly provided
- [ ] Errors don't crash the app
- [ ] Network errors are handled gracefully
- [ ] Permission denials show appropriate guidance
- [ ] Error alerts have proper dismiss actions
- [ ] Retry options are available where appropriate

## Empty States

- [ ] Empty states have helpful, friendly messages
- [ ] Call-to-action buttons where appropriate
- [ ] Illustrations or icons for visual interest
- [ ] Consistent styling with rest of app
- [ ] Empty states don't look like errors
- [ ] Guidance on how to add content

## Touch Targets

- [ ] Minimum 44pt x 44pt touch targets
- [ ] Adequate spacing between tap targets
- [ ] Visual feedback on tap (highlight, scale)
- [ ] No missed taps or unresponsive areas
- [ ] Buttons respond immediately to touch
- [ ] Double-tap prevention where needed

## Forms

- [ ] Clear labels for all input fields
- [ ] Validation feedback is immediate and clear
- [ ] Keyboard types are appropriate (numeric, email, etc.)
- [ ] Return key advances to next field or submits
- [ ] Required fields are marked
- [ ] Character limits are enforced and shown
- [ ] Input fields have proper focus styles

## Navigation

- [ ] Back buttons work correctly
- [ ] Swipe-to-go-back gesture works
- [ ] Navigation titles are clear and accurate
- [ ] Tab bar is always accessible (when appropriate)
- [ ] Deep links work correctly
- [ ] Navigation state is preserved on orientation change
- [ ] Modal dismissal works correctly

## Lists and Grids

- [ ] Pull-to-refresh works where expected
- [ ] Scroll performance is smooth
- [ ] Long lists use lazy loading
- [ ] Grid layouts adapt to screen sizes
- [ ] Selection states are clear
- [ ] Swipe actions work correctly
- [ ] Empty list states are handled

## Images

- [ ] Images load without blocking UI
- [ ] Placeholder/loading states for images
- [ ] Images are properly sized (no pixelation)
- [ ] @2x and @3x assets provided
- [ ] Image memory is managed properly
- [ ] Broken image states handled gracefully

## Accessibility

- [ ] VoiceOver labels are meaningful and complete
- [ ] VoiceOver navigation order is logical
- [ ] Dynamic Type is fully supported
- [ ] Color is not the only indicator of state
- [ ] Focus order follows visual layout
- [ ] Accessibility hints provided where helpful
- [ ] Custom actions are properly labeled
- [ ] Contrast ratios meet WCAG guidelines

## Device Compatibility

- [ ] Works on iPhone SE (small screen)
- [ ] Works on iPhone 15 Pro Max (large screen)
- [ ] Works on older devices (iPhone 8, etc.)
- [ ] Notch/Dynamic Island properly handled
- [ ] Home indicator area respected
- [ ] Landscape orientation (if supported)
- [ ] iPad layout (if supported)

## Performance

- [ ] App launches in under 2 seconds
- [ ] Scrolling maintains 60fps
- [ ] No visible memory leaks
- [ ] Background tasks don't affect UI
- [ ] Large photo libraries are handled
- [ ] Export operations don't freeze UI

## Edge Cases

- [ ] Very long text doesn't break layout
- [ ] Empty data states are handled
- [ ] Network timeouts are handled
- [ ] Interrupted operations recover gracefully
- [ ] App state restores after backgrounding
- [ ] Low storage warnings handled

## Final Visual Check

- [ ] No debug UI visible in release build
- [ ] No placeholder content remaining
- [ ] App icon displays correctly
- [ ] Launch screen appears correctly
- [ ] Onboarding flow works smoothly
- [ ] All screens have been reviewed
- [ ] Dark mode fully tested
- [ ] Light mode fully tested

---

## Sign-Off

**Reviewed By:** _______________
**Date:** _______________
**Build Version:** _______________

### Notes:
