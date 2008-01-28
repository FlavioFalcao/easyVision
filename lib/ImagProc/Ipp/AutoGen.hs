{-# OPTIONS #-}

-----------------------------------------------------------------------------
{- |
Module      :  ImagProc.Ipp.AutoGen
Copyright   :  (c) Alberto Ruiz 2006-8
License     :  GPL-style

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  very provisional
Portability :  hmm...

Generators of Haskell style functions from IPP wrappers

-}
-----------------------------------------------------------------------------

module ImagProc.Ipp.AutoGen(
    auto_0_8u_C1R,
    auto_0_8u_C3R,
    auto_0_32f_C1R,

    auto_1_8u_C1R,
    auto_1_8u_C3R,
    auto_1_32f_C1R,
    auto_1_8u_C3C1R,
    auto_1_8u32f_C1R,
    auto_1_32f8u_C1R,

    auto_1_8u_P3C3R,
    auto_1_8u_C3P3R,
    auto_1_8u_P3R,
    auto_1_8u_C1C3R,
    auto_1_32f_C1MR,

    auto_2_8u_C1R,
    auto_2_32f_C1R,
    auto_2_8u_C1RSfs

) where

import ImagProc.Ipp.Core

------------------------------------------------

auto_0_8u_C1R f msg sz = do
    G r <- image sz
    f // dst r (vroi r) // checkIPP msg []
    return (G r)

auto_0_8u_C3R f msg sz = do
    C r <- image sz
    f // dst r (vroi r) // checkIPP msg []
    return (C r)

auto_0_32f_C1R f msg sz = do
    F r <- image sz
    f // dst r (vroi r) // checkIPP msg []
    return (F r)

------------------------------------------------

imgAsR1 roifun im = do 
    r <- imgAs im
    return r {vroi = roifun (vroi im)}

cr1 f msg im r = f // src im (vroi im) // dst r (vroi r) // checkIPP msg [im]

auto_1_8u_C1R f msg roifun (G im) = do
    r <- imgAsR1 roifun im
    cr1 f msg im r
    return (G r)

auto_1_8u_C3R f msg roifun (C im) = do
    r <- imgAsR1 roifun im
    cr1 f msg im r
    return (C r)

auto_1_32f_C1R f msg roifun (F im) = do
    r <- imgAsR1 roifun im
    cr1 f msg im r
    return (F r)

auto_1_8u_C3C1R f msg roifun (C im) = do
    r' <- img Gray (isize im)
    let r = r' { vroi = roifun (vroi im) }
    cr1 f msg im r
    return (G r)

auto_1_8u32f_C1R f msg roifun (G im) = do
    r' <- img I32f (isize im)
    let r = r' { vroi = roifun (vroi im) }
    cr1 f msg im r
    return (F r)

auto_1_32f8u_C1R f msg roifun (F im) = do
    r' <- img Gray (isize im)
    let r = r' { vroi = roifun (vroi im) }
    cr1 f msg im r
    return (G r)

auto_1_8u_P3C3R = error $ "auto_1_8u_P3C3R not yet defined"
auto_1_8u_C3P3R = error $ "auto_1_8u_C3P3R not yet defined"
auto_1_8u_P3R = error $ "auto_1_8u_P3R not yet defined"
auto_1_8u_C1C3R = error $ "auto_1_8u_C1C3R not yet defined"
auto_1_32f_C1MR = error $ "auto_1_32f_C1MR not yet defined"

----------------------------------------------------------

imgAsR2 roifun im1 im2 = do 
    r <- imgAs im1
    return r {vroi = roifun (vroi im1) (vroi im2)}

cr2 f msg im1 im2 r = f // src im1 (vroi im1) // src im2 (vroi im2)// dst r (vroi r) // checkIPP msg [im1,im2]

auto_2_8u_C1R f msg roifun (G im1) (G im2) = do
    r <- imgAsR2 roifun im1 im2
    cr2 f msg im1 im2 r
    return (G r)

auto_2_32f_C1R f msg roifun (F im1) (F im2) = do
    r <- imgAsR2 roifun im1 im2
    cr2 f msg im1 im2 r
    return (F r)

auto_2_8u_C1RSfs = auto_2_8u_C1R