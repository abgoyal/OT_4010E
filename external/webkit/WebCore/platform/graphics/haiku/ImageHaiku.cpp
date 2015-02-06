

#include "config.h"
#include "Image.h"

#include "BitmapImage.h"
#include "FloatRect.h"
#include "GraphicsContext.h"
#include "ImageObserver.h"
#include "NotImplemented.h"
#include "PlatformString.h"
#include "TransformationMatrix.h"
#include <Application.h>
#include <Bitmap.h>
#include <View.h>

// This function loads resources from WebKit
Vector<char> loadResourceIntoArray(const char*);


namespace WebCore {

bool FrameData::clear(bool clearMetadata)
{
    if (clearMetadata)
        m_haveMetadata = false;

    if (m_frame) {
        delete m_frame;
        m_frame = 0;
        m_duration = 0.0f;
        m_hasAlpha = true;
        return true;
    }

    return false;
}

WTF::PassRefPtr<Image> Image::loadPlatformResource(const char* name)
{
    Vector<char> array = loadResourceIntoArray(name);
    WTF::PassRefPtr<BitmapImage> image = BitmapImage::create();
    RefPtr<SharedBuffer> buffer = SharedBuffer::create(array.data(), array.size());
    image->setData(buffer, true);

    return image;
}

void BitmapImage::initPlatformData()
{
}

void BitmapImage::invalidatePlatformData()
{
}

// Drawing Routines
void BitmapImage::draw(GraphicsContext* ctxt, const FloatRect& dst, const FloatRect& src, ColorSpace styleColorSpace, CompositeOperator op)
{
    if (!m_source.initialized())
        return;

    // Spin the animation to the correct frame before we try to draw it, so we
    // don't draw an old frame and then immediately need to draw a newer one,
    // causing flicker and wasting CPU.
    startAnimation();

    BBitmap* image = nativeImageForCurrentFrame();
    if (!image || !image->IsValid()) // If the image hasn't fully loaded.
        return;

    if (mayFillWithSolidColor()) {
        fillWithSolidColor(ctxt, dst, solidColor(), styleColorSpace, op);
        return;
    }

    ctxt->save();
    ctxt->setCompositeOperation(op);

    BRect srcRect(src);
    BRect dstRect(dst);

    // Test using example site at
    // http://www.meyerweb.com/eric/css/edge/complexspiral/demo.html
    ctxt->platformContext()->SetDrawingMode(B_OP_ALPHA);
    ctxt->platformContext()->DrawBitmapAsync(image, srcRect, dstRect);
    ctxt->restore();

    if (imageObserver())
        imageObserver()->didDraw(this);
}

void Image::drawPattern(GraphicsContext* context, const FloatRect& tileRect, const AffineTransform& patternTransform, const FloatPoint& srcPoint, ColorSpace, CompositeOperator op, const FloatRect& dstRect)
{
    BBitmap* image = nativeImageForCurrentFrame();
    if (!image || !image->IsValid()) // If the image hasn't fully loaded.
        return;

    // Figure out if the image has any alpha transparency, we can use faster drawing if not
    bool hasAlpha = false;

    uint8* bits = reinterpret_cast<uint8*>(image->Bits());
    uint32 width = image->Bounds().IntegerWidth() + 1;
    uint32 height = image->Bounds().IntegerHeight() + 1;

    uint32 bytesPerRow = image->BytesPerRow();
    for (uint32 y = 0; y < height && !hasAlpha; y++) {
        uint8* p = bits;
        for (uint32 x = 0; x < width && !hasAlpha; x++) {
            hasAlpha = p[3] < 255;
            p += 4;
        }
        bits += bytesPerRow;
    }

    context->save();
    if (hasAlpha)
        context->platformContext()->SetDrawingMode(B_OP_ALPHA);
    else
        context->platformContext()->SetDrawingMode(B_OP_COPY);
    context->clip(enclosingIntRect(dstRect));
    float currentW = phase.x();
    BRect bTileRect(tileRect);
    while (currentW < dstRect.x() + dstRect.width()) {
        float currentH = phase.y();
        while (currentH < dstRect.y() + dstRect.height()) {
            BRect bDstRect(currentW, currentH, currentW + width - 1, currentH + height - 1);
            context->platformContext()->DrawBitmapAsync(image, bTileRect, bDstRect);
            currentH += height;
        }
        currentW += width;
    }
    context->restore();

    if (imageObserver())
        imageObserver()->didDraw(this);
}

void BitmapImage::checkForSolidColor()
{
    m_isSolidColor = false;
    m_checkedForSolidColor = true;

    if (frameCount() > 1)
        return;

    BBitmap* image = getBBitmap();
    if (!image || !image->Bounds().IsValid()
        || image->Bounds().IntegerWidth() > 0 || image->Bounds().IntegerHeight() > 0) {
        return;
    }

    m_isSolidColor = true;
    uint8* bits = reinterpret_cast<uint8*>(image->Bits());
    m_solidColor = Color(bits[2], bits[1], bits[0], bits[3]);
}

BBitmap* BitmapImage::getBBitmap() const
{
    return const_cast<BitmapImage*>(this)->frameAtIndex(0);
}

} // namespace WebCore

