{-# LANGUAGE MagicHash, UnboxedTuples, BangPatterns #-}
-----------------------------------------------------------------------------
{- |
Module      :  ImagProc.ImageFold
Copyright   :  (c) Alberto Ruiz 2008
License     :  GPL-style

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  provisional
Portability :  ghc

Low level utilities to traverse images.

-}
-----------------------------------------------------------------------------

module ImagProc.ImageFold (
    foldImage, foldImage2, foldImage3,
    traverseImage3,
    uval
)
where

import ImagProc.Ipp.Core
import Numeric.LinearAlgebra hiding (step)
import System.IO.Unsafe(unsafePerformIO)
import Foreign.Storable
import Foreign.Ptr
import Foreign.ForeignPtr
import Foreign.Marshal.Array
import Control.Monad(when)
import GHC.Prim

import GHC.Base
import GHC.IOBase

inlinePerformIO :: IO a -> a
inlinePerformIO (IO m) = case m realWorld# of (# _, r #) -> r
{-# INLINE inlinePerformIO #-}

uval !p !k = inlinePerformIO $ peekElemOff p k
{-# INLINE uval #-}

--foldImage :: (Ptr Float -> Int -> Int -> Int -> t -> t) -> t -> ImageFloat -> t
foldImage f x (F img) =
    unsafePerformIO $ withForeignPtr (fptr img) $ const
                    $ return (go tot x)
    where jump = step img `div` datasize img
          ROI r1 r2 c1 c2 = vroi img
          p = advancePtr (castPtr (ptr img)) (r1*jump+c1) :: Ptr Float
          c = c2-c1+1
          d = jump - c
          tot = (r2 - r1) * jump + c2-c1

          go 0 !s = f p (0::Int) s
          go !j !s = if ok then go (j-1) (f p j s)
                           else go (j-d) s
            where ok = {-# SCC "rem" #-} remInt j jump < c
{-# INLINE foldImage #-}

foldImage2 f x (F img1) (F img2) =
    unsafePerformIO $ withForeignPtr (fptr img1) $ const
                    $ withForeignPtr (fptr img2) $ const
                    $ return (go tot x)
    where jump = step img1 `div` datasize img1
          ROI r1 r2 c1 c2 = vroi img1
          p1 = advancePtr (castPtr (ptr img1)) (r1*jump+c1) :: Ptr Float
          p2 = advancePtr (castPtr (ptr img2)) (r1*jump+c1) :: Ptr Float
          c = c2-c1+1
          d = jump - c
          tot = (r2 - r1) * jump + c2-c1

          go 0 s = f p1 p2 (0::Int) s
          go !j !s = if j `rem` jump < c then go (j-1) (f p1 p2 j s)
                                         else go (j-d) s
{-# INLINE foldImage2 #-}

foldImage3 f x (F img1) (F img2) (F img3 ) =
    unsafePerformIO $ withForeignPtr (fptr img1) $ const
                    $ withForeignPtr (fptr img2) $ const
                    $ withForeignPtr (fptr img3) $ const
                    $ return (go tot x)
    where jump = step img1 `div` datasize img1
          ROI r1 r2 c1 c2 = vroi img1
          p1 = advancePtr (castPtr (ptr img1)) (r1*jump+c1) :: Ptr Float
          p2 = advancePtr (castPtr (ptr img2)) (r1*jump+c1) :: Ptr Float
          p3 = advancePtr (castPtr (ptr img3)) (r1*jump+c1) :: Ptr Float
          c = c2-c1+1
          d = jump - c
          tot = (r2 - r1) * jump + c2-c1

          go 0 s = f p1 p2 p3 (0::Int) s
          go !j !s = if j `rem` jump < c then go (j-1) (f p1 p2 p3 j s)
                                         else go (j-d) s
{-# INLINE foldImage3 #-}

traverseImage3 f (F img1) (F img2) (F img3 ) =
    unsafePerformIO $ withForeignPtr (fptr img1) $ const
                    $ withForeignPtr (fptr img2) $ const
                    $ withForeignPtr (fptr img3) $ const
                    $ return (go tot)
    where jump = step img1 `div` datasize img1
          ROI r1 r2 c1 c2 = vroi img1
          p1 = advancePtr (castPtr (ptr img1)) (r1*jump+c1) :: Ptr Float
          p2 = advancePtr (castPtr (ptr img2)) (r1*jump+c1) :: Ptr Float
          p3 = advancePtr (castPtr (ptr img3)) (r1*jump+c1) :: Ptr Float
          c = c2-c1+1
          d = jump - c
          tot = (r2 - r1) * jump + c2-c1

          go 0 = f p1 p2 p3 (0::Int)
          go !j = if j `rem` jump < c
                    then f p1 p2 p3 j >> go (j-1)
                    else go (j-d)
{-# INLINE traverseImage3 #-}
