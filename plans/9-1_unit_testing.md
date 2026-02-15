# Unit Testing for Core Systems - Redotian Sun

## Overview
Comprehensive unit testing ensures code quality and reliability across all core RTS systems. Tests validate functionality before integration with other modules.

## Test Coverage Requirements

### 1. Camera & Selection System Tests
- **Camera Movement**: Verify smooth panning/zooming within bounds
- **Box Selection**: Test raycasting accuracy for multi-select
- **Group Management**: Validate hotkey-based group save/load
- **Smart Centering**: Confirm camera auto-positioning on selection

### 2. Base Building System Tests
- **Placement Validation**: Test terrain/power/proximity rules
- **Construction Queue**: Verify FIFO ordering and completion timing
- **Power Grid**: Check overload protection and visual feedback
- **Destruction Logic**: Validate resource refunds on building death

### 3. Economy & Resources Tests
- **Resource Generation**: Confirm income rates calculate correctly
- **Expense Validation**: Test affordability checks before production
- **Tiberium Harvesting**: Verify collection loop (harvester → refinery)
- **Storage Limits**: Ensure caps are enforced properly

### 4. Unit Production Pipeline Tests
- **Queue Management**: Validate slot limits and priority ordering
- **Prerequisite Checks**: Confirm tech tree unlock requirements work
- **Spawn Logic**: Test unit instantiation at production locations
- **Cancel Refunds**: Verify partial refund calculations

## Technical Implementation

### Testing Framework
- Use Godot's built-in `@tool` scripts for editor testing
- Leverage `ClassDB` and `SceneTree` mocks where needed
- Implement integration tests using test scenes with mocked systems
- Run tests via CI/CD pipeline on every commit

### Test Example Structure
```gdscript
@tool
extends SceneTester

func test_camera_zoom_clamping():
    var camera = get_test_instance("MainCamera")
    
    # Zoom beyond minimum should clamp to min value
    camera.zoom_to(20.0)
    assert(camera.zoom == 50.0, "Zoom clamped to minimum")
    
    # Zoom beyond maximum should clamp to max value  
    camera.zoom_to(1000.0)
    assert(camera.zoom == 400.0, "Zoom clamped to maximum")

func test_box_selection_raycasting():
    var selection = get_test_instance("SelectionSystem")
    
    # Define box corners in screen space
    var box_points = [Vector2(100, 100), Vector2(300, 100), 
                       Vector2(300, 300), Vector2(100, 300)]
    
    # Cast rays and verify units selected
    var selected = selection.get_selected_in_box(box_points)
    assert(selected.size() == 5, "Should select 5 units in box")
```

### Test Data Setup
- Create predefined map layouts for reproducible tests
- Mock unit/building instances with known stats
- Seed random generators for deterministic testing
- Use fixtures for common setup/teardown logic

## Integration Points
- Connect to economy system for resource test scenarios
- Link with production manager for queue validation tests
- Coordinate with camera system for movement boundary checks
- Interface with save/load for persistence test cases

## Future Enhancements
- Automated performance profiling in test suite
- Visual regression testing for UI changes
- A/B testing for balance adjustments
- Coverage reporting dashboard for development tracking
