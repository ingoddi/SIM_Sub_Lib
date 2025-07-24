import SwiftUI


public extension View {
    /// Очищает весь видеокэш при уходе с экрана
    func clearAllVideoCacheOnDisappear(
        _ action: @escaping () -> Void = {
            CelestialVideoCache.shared.clearAll()
        }
    ) -> some View {
        modifier(ClearVideoCacheModifier(clearAction: action))
    }

    /// Очищает конкретное видео по имени при уходе с экрана
    func clearVideoCacheOnDisappearByName(_ name: String) -> some View {
        modifier(ClearVideoCacheModifier(clearAction: {
            CelestialVideoCache.shared.clear(name: name)
        }))
    }
}

public extension View {
    func backgroundCleaner(stepIndex: Int, previousVideo: Binding<String?>) -> some View {
        self.modifier(BackgroundCleanerModifier(stepIndex: stepIndex, previousVideo: previousVideo))
    }
}

public extension View {
    /// Маскирует видео (или любой контент) по форме картинки
    /// - Parameter imageName: имя изображения (например, экспортированное из Figma)
    func videoMask(_ imageName: String) -> some View {
        self.mask(
            Image(imageName)
                .resizable()
                .scaledToFit()
        )
    }
}



