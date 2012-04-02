{-# LANGUAGE Arrows #-}
{-# LANGUAGE BangPatterns #-}

-----------------------------------------------------------------------------
{- |
Module      :  Vision.GUI.Arrow
Copyright   :  (c) Alberto Ruiz 2012
License     :  GPL

Maintainer  :  Alberto Ruiz (aruiz at um dot es)

Arrow interface.

-}
-----------------------------------------------------------------------------

module Vision.GUI.Arrow(
    runITrans, runT_, runT, runS, ITrans(ITrans), transUI, arrL, (@@@), delay', arrIO,
    runNT_
)where

import Control.Concurrent   (forkIO)
import Util.LazyIO          (mkGenerator, lazyList, grabAll, createGrab)
import Vision.GUI.Interface (runIt,VC,VCN)

import qualified Control.Category as Cat
import Control.Arrow
import Control.Monad
import Data.Either(lefts,rights)
import System.IO.Unsafe(unsafeInterleaveIO)
import Control.Concurrent
import Graphics.UI.GLUT (mainLoopEvent)

--------------------------------------------------------------------------------

-- | transformation of a sequence
newtype Trans a b = Trans ( [a] -> IO [b] )

newtype ITrans a b = ITrans (IO (Trans a b))

instance Cat.Category Trans
  where
    id = Trans return 
    Trans f . Trans g = Trans ( g >=> f )

instance Cat.Category ITrans
  where
    id = ITrans $ return (arr id)
    ITrans gf . ITrans gg = ITrans (liftM2 (>>>) gg gf)

instance Arrow Trans
  where
    arr f = Trans (return . map f)
    first f = f *** Cat.id
    (***) (Trans s) (Trans t) = Trans r
      where
        r = g . (s *** t) . unzip
        g (a,b) = do
            as <- a
            bs <- b
            return (zip as bs)

instance Arrow ITrans
  where
    arr f = ITrans (return (arr f))
    first f = f *** Cat.id
    ITrans f *** ITrans g = ITrans $ liftM2 (***) f g



arrL :: ([a]->[b]) -> ITrans a b
-- ^ pure function on the whole list of results
arrL f = ITrans (return (Trans (return . f)))


--------------------------------------------------------------------------------

transUI :: VCN a b -> ITrans a b
transUI gf = ITrans $ do
    f <- gf
    return $ Trans $ \as -> do
        ga <- createGrab as
        grabAll (f ga)


arrIO :: (a -> IO b) -> ITrans a b
-- ^ lift an IO action to the ITrans arrow
arrIO f = transUI . return $ \c -> c >>= f

--------------------------------------------------------------------------------

(@@@) :: (p -> x -> y) -> IO (IO p) -> ITrans x y
-- ^ apply a pure function with parameters taken from the UI
infixl 3 @@@
f @@@ p = arr (uncurry f) <<< (transUI (fmap const p) &&& arr id)

------------------------------------------------------------------

instance ArrowChoice Trans where
    left f = f +++ arr id
    Trans f +++ Trans g = Trans $ \xs -> do
        ls <- unsafeInterleaveIO $ f (lefts xs)
        rs <- unsafeInterleaveIO $ g (rights xs)
        return (merge ls rs xs)

merge :: [a] -> [b] -> [Either x y] -> [Either a b]
merge _  _ [] = []
merge ls rs (x:xs) =
    case x of
         Right _ -> Right (head rs): merge ls (tail rs) xs
         Left  _ -> Left  (head ls): merge (tail ls) rs xs

--------------------------------------------------------------------------------

instance ArrowChoice ITrans where
   left f = f +++ arr id
   ITrans f +++ ITrans g = ITrans $ liftM2 (+++) f g

--------------------------------------------------------------------------------

delay' :: ITrans a a
-- ^ similar to delay from ArrowCircuit, initialized with the first element
delay' = arrL f
  where
    f [] = []
    f (a:as) = a:a:as

--------------------------------------------------------------------------------

runITrans :: ITrans a b -> [a] -> IO [b]
runITrans (ITrans gt) as = do
    Trans t <- gt
    t as


runT_ :: IO (IO a) -> ITrans a b -> IO ()
-- ^ run a camera generator on a transformer
runT_ gcam gt = runIt $ do
    bs <- runS gcam gt
    forkIO $ mapM_ g bs
  where
    g !_x = putStr ""


runNT_ :: IO (IO a) -> ITrans a b -> IO ()
-- ^ run process without fork, (needs explicit "prepare").
-- This is currently required for certain GPU applications.
runNT_ gcam gt = do
    bs <- runS gcam gt
    mapM_ g bs
  where
    g !_x = putStr "" >> mainLoopEvent


runT :: IO (IO a) -> ITrans a b -> IO [b]
-- ^ run a camera generator on a transformer, returning the results in a lazy list
runT gcam gt = do
    rbs <- newChan
    forkIO $ runIt $ do
        bs <- runS gcam gt
        forkIO $ mapM_ (writeChan rbs) bs
    getChanContents rbs


runS :: IO (IO a) -> ITrans a b -> IO [b]
-- ^ runT without the GUI (run silent) 
runS gcam gt = gcam >>= grabAll >>= runITrans gt

