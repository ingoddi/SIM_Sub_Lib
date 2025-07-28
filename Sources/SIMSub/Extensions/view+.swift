import SwiftUI




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



