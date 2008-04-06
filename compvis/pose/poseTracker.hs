import EasyVision
import Vision
import Graphics.UI.GLUT hiding (Matrix, Size, Point,set)
import Text.Printf
import Numeric.LinearAlgebra
import Control.Monad(when)

disp m = putStrLn . format " " (printf "%5.2f") $ m

asym = map (map (*0.54))
       [ [ 0, 0]
       , [ 0, 2]
       , [ 1, 2]
       , [ 2, 1]
       , [ 2, 0] ]

main = do
    prepare
    sz <- findSize
    mbf <- maybeOption "--focal"
    let ref = asym

    cam <- getCam 0 sz >>= withChannels >>= findPolygons mbf ref >>= poseTracker "visor" mbf ref

    w <- evWindow () "img" sz Nothing (const $ kbdQuit)

    launch $ do
        (img,pose,(st,cov),obs) <- cam

        inWin w $ do
            drawImage (gray img)

            pointCoordinates (size (gray img))

            setColor 1 0 0
            lineWidth $= 3
            renderPrimitive LineLoop $ mapM_ vertex (ht (syntheticCamera pose) (map (++[0]) ref))

            --disp $ fromRows [st, sqrt $ takeDiag cov]
            --disp $ cov

            case obs of
                Nothing -> return ()
                Just (fig,p) -> do
                    setColor 0 0.5 0
                    lineWidth $= 3
                    renderPrimitive LineLoop $ mapM_ vertex fig
