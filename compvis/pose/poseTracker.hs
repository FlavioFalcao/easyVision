import EasyVision
import Vision
import Graphics.UI.GLUT hiding (Matrix, Size, Point,set)
import Text.Printf
import Numeric.LinearAlgebra
import Control.Monad(when)
import Numeric.GSL.Fourier

disp m = putStrLn . format " " (printf "%5.2f") $ m

asym = map (map (*0.54))
       [ [ 0, 0]
       , [ 0, 2]
       , [ 1, 2]
       , [ 2, 1]
       , [ 2, 0] ]

a4 = [[   0, 0]
     ,[   0, r]
     ,[   1, r]
     ,[   1, 0]] where r = sqrt 2


main = do
    prepare
    sz <- findSize
    mbf <- maybeOption "--focal"
    let ref = asym

    cam <- getCam 0 sz >>= withChannels >>= poseTracker "visor" mbf ref

    w <- evWindow () "img" sz Nothing (const $ kbdQuit)

    launchFreq 25 $ do
        (img,pose,(st,cov),obs) <- cam

        inWin w $ do
            drawImage (gray img)

            pointCoordinates (size (gray img))

            setColor 1 0 0
            lineWidth $= 3
            renderPrimitive LineLoop $ mapM_ vertex (ht (syntheticCamera pose) (map (++[0]) ref))

            --disp $ fromRows [st, sqrt $ takeDiag cov]
            --disp $ cov
            --text2D 0.9 0.7 (printf "%.1f"  $ sum $ drop (dim st - 9) $ take (dim st -6) $ toList $ sqrt $ takeDiag cov)

            case obs of
                Nothing -> return ()
                Just (v,err) -> do
                    setColor 1 0 0
                    text2D 0.9 0.7 (printf "%.1f" err)
                    setColor 0.8 0.8 0
                    lineWidth $= 2
                    if dim v == 10
                        then do let fig = toLists $ reshape 2 v
                                renderPrimitive LineLoop $ mapM_ vertex fig
                        else do let w = (dim v `div` 2 - 1) `div` 2
                                    fig = invFou 50 w . map l2c $ toLists $ reshape 2 v
                                    Closed l = fig
                                shcont fig

l2c [x,y] = (x:+y)

invFou n w fou = Closed r where
    f = fromList $ map (fou!!) [w..2*w] ++ replicate (n-7) 0 ++ map (fou!!) [0..w-1]
    r = map c2p $ toList $ ifft (fromIntegral n *f)
    c2p (x:+y) = Point x y


shcont (Closed c) = do
    renderPrimitive LineLoop $ mapM_ vertex c
    --pointSize $= 5
    --renderPrimitive Points (vertex (head c))