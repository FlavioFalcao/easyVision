{-# LANGUAGE RecordWildCards #-}


module ImagProc.Ipp.Generic(
    Pix(..),
    warp,
    resizeFull,
    constant,
    Channels(..),channelsFromRGB, grayscale, grayf
) where

import Image.Devel
import ImagProc.Ipp.AdHoc
import ImagProc.Ipp.Pure
import Numeric.LinearAlgebra(Matrix, toLists, (<>), inv, rows, cols)
import Control.Arrow((&&&))

class Storable p => Pix p
  where
    copy   :: Image p -> [(Image p, Pixel)]         -> Image p
    set    :: Image p -> [(ROI, p)]                 -> Image p
    resize :: Size    -> Image p                    -> Image p
    warpon :: Image p -> [(Matrix Double, Image p)] -> Image p
    crossCorr :: Image p -> Image p -> Image Float
    sqrDist   :: Image p -> Image p -> Image Float
    uradial :: Float -- ^ f parameter in normalized coordinates (e.g. 2.0)
            -> Float -- ^ k radial distortion (quadratic) parameter
            -> Image p -> Image p

instance Pix Word8
  where
    copy    = layerImages copy8u
    set     = setROIs set8u
    resize  = selresize resize8u resize8uNN
    warpon  = warpong warpon8u
    uradial = uradialG undistortRadial8u
    crossCorr = crossCorr8u
    sqrDist = sqrDist8u

instance Pix Word24
  where
    copy   = layerImages copy8u3
    set    = setROIs set8u3
    resize = selresize resize8u3 resize8u3NN
    warpon = warpong warpon8u3
    uradial = uradialG undistortRadial8u3
    crossCorr = crossCorr8u3
    sqrDist = sqrDist8u3

instance Pix Float
  where
    copy   = layerImages copy32f
    set    = setROIs set32f
    resize = selresize resize32f resize32fNN
    warpon = warpong warpon32f
    uradial = uradialG undistortRadial32f
    crossCorr = crossCorr32f
    sqrDist = sqrDist32f

resizeFull :: Pix p => Size -> Image p -> Image p
resizeFull sz'@(Size h' w') im = unsafePerformIO $ do
    r <- newImage undefined sz'
    return $ setROI newroi $ copy r [(x,Pixel r1' c1')]
 where
    Size h w = size im
    sr@(ROI r1 _ c1 _) = roi im
    Size rh rw = roiSize sr
    fh = g h' / g h :: Double
    fw = g w' / g w :: Double
    rh' = round (g rh*fh)
    rw' = round (g rw*fw)
    r1' = round (g r1*fh)
    c1' = round (g c1*fw)
    x = resize (Size rh' rw') im
    newroi = shift (r1',c1') (roi x)
    g n = fromIntegral n


constant :: Pix p => p -> Size -> Image p
constant v sz = unsafePerformIO $ do
    r <- newImage undefined sz
    return $ set r [(fullROI sz, v)]


warp :: Pix p => p -> Size -> Matrix Double -> Image p -> Image p
warp p sz h im = warpon (constant p sz) [(h,im)]


{-

{-# LANGUAGE MultiParamTypeClasses, FunctionalDependencies, FlexibleInstances #-}
{-# LANGUAGE RecordWildCards #-}

-----------------------------------------------------------------------------
{- |
Module      :  ImagProc.Generic
Copyright   :  (c) Alberto Ruiz 2007-10
License     :  GPL

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  provisional

-}
-----------------------------------------------------------------------------

module ImagProc.Generic (
  GImg(..)
, blockImage
, warp, warpOn, warpOn'
, constImage, cloneClear, clean
, Channels(..), channels, grayscale, grayf
, channelsFromRGB
, resizeFull
, layerImages
)
where

import ImagProc.Ipp
import System.IO.Unsafe(unsafePerformIO)
import Numeric.LinearAlgebra
import Util.Misc(debug)

class Image image => GImg pixel image | pixel -> image, image -> pixel where
    zeroP :: pixel
    set :: pixel -> ROI -> image -> IO ()
    copy :: image -> ROI -> image -> ROI -> IO ()
    -- | Resizes the roi of a given image.
    resize :: Size -> image -> image
    clone :: image -> IO image
    warpOnG :: [[Double]] -> image -> image -> IO ()
    fromYUV :: ImageYUV -> image
    toYUV :: image -> ImageYUV
    -- | transform an image according to a lookup table (see 'undistortMap')
    remap :: LookupMap -> InterpolationMode -> image -> image
    -- | convencience wrapper of undistortRadial for diag f f 1 cameras
    uradial :: Float -- ^ f parameter in normalized coordinates (e.g. 2.0)
            -> Float -- ^ k radial distortion (quadratic) parameter
            -> image -> image
    crossCorr :: image -> image -> ImageFloat
    sqrDist   :: image -> image -> ImageFloat

----------------------------------

instance GImg CUChar Image Word8
  where
    zeroP = 0
    set = set8u
    copy = copyROI8u
    resize = resize8u InterpLinear
    clone = ioCopy_8u_C1R id
    warpOnG = warpOn8u
    fromYUV = yuvToGray
    toYUV = grayToYUV . clean
    remap (LookupMap m) = remap8u m
    uradial = uradialG undistortRadial8u
    crossCorr = crossCorrGray
    sqrDist = sqrDistGray

instance GImg Float ImageFloat
  where
    zeroP = 0
    set = set32f
    copy = copyROI32f
    resize = resize32f InterpLinear
    clone = ioCopy_32f_C1R id
    warpOnG = warpOn32f
    fromYUV = float . yuvToGray
    toYUV = grayToYUV . clean . toGray
    remap (LookupMap m) = remap32f m
    uradial = uradialG undistortRadial32f
    crossCorr = crossCorrFloat
    sqrDist = sqrDistFloat

instance GImg (CUChar,CUChar,CUChar) ImageRGB
  where
    zeroP = (0,0,0)
    set (r,g,b) = set8u3 r g b
    copy = copyROI8u3
    resize = resize8u3 InterpLinear
    clone = ioCopy_8u_C3R id
    warpOnG = warpOn8u3
    fromYUV = yuvToRGB
    toYUV = rgbToYUV . clean
    remap (LookupMap m) = remapRGB m
    uradial = uradialG undistortRadialRGB
    crossCorr t = r3 . crossCorrRGB t
    sqrDist t = r3 . sqrDistRGB t

r3 x = resizeFull (Size r (c `div` 3)) x
  where
    Size r c = size x


--------------------------------------------------------------------------

-- | joins images
blockImage :: GImg p img  => [[img]] -> img
blockImage = columnImage . map rowImage

--rowImage :: [Image Word8] -> Image Word8
rowImage l = unsafePerformIO $ do
    let r = maximum (map (height.size) l)
        c = maximum (map (width.size) l)
        n = length l
    res <- image (Size r (c*n))
    let f i k = do copy i roi res (m roi)
                   mapM_ (flip (set zeroP) res) (map m (invalidROIs i))
            where m = shift (0,k*c)
                  roi = theROI i
    sequence_ $ zipWith f l [0..]
    return res

--columnImage :: [Image Word8] -> Image Word8
columnImage l = unsafePerformIO $ do
    let r = maximum (map (height.size) l)
        c = maximum (map (width.size) l)
        n = length l
    res <- image (Size (r*n) c)
    let f i k = do copy i roi res (m roi)
                   mapM_ (flip (set zeroP) res) (map m (invalidROIs i))
            where m = shift (k*r,0)
                  roi = theROI i
    sequence_ $ zipWith f l [0..]
    return res

---------------------------------------------------------------------------------

-}

data Channels = CHIm
    { yuv  :: ImageYUV
    , yCh  :: Image Word8
    , uCh  :: Image Word8
    , vCh  :: Image Word8
    , rgb  :: Image Word24
    , rCh  :: Image Word8
    , gCh  :: Image Word8
    , bCh  :: Image Word8
    , hsv  :: Image Word24
    , hCh  :: Image Word8
    , sCh  :: Image Word8
    , fCh  :: Image Float
    }

grayscale :: Channels -> Image Word8
grayscale = yCh

grayf :: Channels -> Image Float
grayf = fCh

{-
channels :: ImageYUV -> Channels
channels img = CHIm{..}
  where
    yuv = img
    yCh = fromYUV img
    uCh = u
    vCh = v
    rgb = rgbAux
    rCh = getChannel 0 rgbAux
    gCh = getChannel 1 rgbAux
    bCh = getChannel 2 rgbAux
    hsv = hsvAux
    hCh = getChannel 0 hsvAux
    sCh = getChannel 1 hsvAux
    fCh = float yCh
    rgbAux = fromYUV img
    hsvAux = rgbToHSV rgbAux
    (u,v) = yuvToUV img

-}

channelsFromRGB :: Image Word24 -> Channels
channelsFromRGB img = CHIm{..}
  where
    yuv = yuvAux
    yCh = rgbToGray img
    uCh = u
    vCh = v
    rgb = img
    rCh = getChannel 0 img
    gCh = getChannel 1 img
    bCh = getChannel 2 img
    hsv = hsvAux
    hCh = getChannel 0 hsvAux
    sCh = getChannel 1 hsvAux
    fCh = toFloat yCh
    yuvAux = rgbToYUV img
    hsvAux = rgbToHSV img
    (u,v) = yuvToUV yuvAux


--------------------------------------------------------------------------------


layerImages
    :: (Image p -> Image p -> Pixel -> IO ())
    -> Image p -> [(Image p, Pixel)] -> Image p
layerImages g im ptsIms = unsafePerformIO $ do
    res <- cloneImage im
    mapM_ (f res) ptsIms
    return res
  where
    f res (x, p) = g x res p

setROIs
    :: (p -> ROI -> Image p -> IO ())
    -> Image p -> [(ROI, p)] -> Image p
setROIs g im rps = unsafePerformIO $ do
    res <- cloneImage im
    mapM_ (f res) rps
    return res
  where
    f res (x, p) = g p x res


selresize
  :: (Size -> Image p -> t) -> (Size -> Image p -> t)
  -> Size -> Image p -> t
selresize f1 f2 sz im
    | roiArea sr < 1       = error $ "resize input " ++ show sr
    | r1 == r2 || c1 == c2 = f2 sz im
    | otherwise            = f1 sz im
  where
    sr@(ROI r1 r2 c1 c2) = roi im


warpong
  :: ([[Double]] -> Image p -> Image p -> IO ())
     -> Image p -> [(Matrix Double, Image p)] -> Image p
warpong g im hxs = unsafePerformIO $ do
    res <- cloneImage im
    mapM_ (f res) hxs
    return res
  where
    f res (h,x) | ok = g adapt x res
                | otherwise = error $ "warp homography wrong dimensions " ++ show szh
      where
        adapt = toLists $ inv (pixelToPointTrans (size res)) <> h <> pixelToPointTrans (size x)
        szh = (rows &&& cols) h
        ok = szh == (3,3)

uradialG :: (Float -> Float -> Float -> Float -> Float -> Float -> Image p -> Image p)
         -> Float -> Float -> Image p -> Image p
uradialG gen f k im = gen fp fp (fromIntegral w / 2) (fromIntegral h / 2) k 0 im
        where Size h w = size im
              fp = f * fromIntegral w / 2
