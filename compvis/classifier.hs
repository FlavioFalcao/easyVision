
import EasyVision
import ImagProc.Ipp.Core
import Control.Monad(when,(>=>))
import Graphics.UI.GLUT hiding (Point,Size)
import Data.List(minimumBy, sortBy)

purelbp th sz = lbpN th . resize sz . fromYUV

feat im = (im, purelbp 8 (mpSize 4) im)


main = do
    sz <- findSize

    protos <- getProtos feat

    mapM_ print $ take 10 $ sortBy (compare `on` snd) $ report protos

    prepare

    (cam,ctrl) <- getCam 0 sz
                  >>= onlyRectangles (mpSize 10) (sqrt 2)
                  >>= virtualCamera (return . concat)
                  >>= virtualCamera (return . map (toYUV :: ImageRGB -> ImageYUV))
                  >>= withPause

    w <- evWindow (False, protos) "video" sz Nothing  (mouse (kbdcam ctrl))

    r <- evWindow () "category" (mpSize 10)  Nothing  (const (kbdcam ctrl))

    launch (worker cam w r)

-----------------------------------------------------------------

worker cam w r = do

    img@(orig,v) <- feat `fmap` cam

    (click,pats) <- getW w
    when click $ putW w (False, ((img, show (length pats))):pats)

    inWin w $ do
        drawImage orig
        pointCoordinates (size orig)
        setColor 0 0 0
        renderAxes
        setColor 1 0 0
        renderSignal (map (*0.5) v)

    when (not $ null pats) $ inWin r $ do
        let x@((im,_),l) = minimumBy (compare `on` dist img) pats
            d = dist img x
        drawImage im
        pointCoordinates (mpSize 10)
        text2D 0.9 0.6 (l++": "++(show $ round d))
        when (d>10) $ do
            setColor 1 0 0
            lineWidth $= 10
            renderPrimitive Lines $ mapM_ vertex $
                [ Point 1 (-1), Point (-1) 1, Point 1 1, Point (-1) (-1) ]

-----------------------------------------------------

dist (_,u) ((_,v),_) = n2 u v

n2 u v = sum $ map (^2) $ zipWith subtract u v

-----------------------------------------------------

mouse _ st (MouseButton LeftButton) Down _ _ = do
    (_,ps) <- get st
    st $= (True,ps)

mouse _ st (Char 'f') Down _ _ = do
    (_,ps) <- get st
    sv <- openYUV4Mpeg (size $ fst $ fst $ head $ ps) (Just "catalog.avi") Nothing
    mapM_ (sv.fst.fst) ps
    writeFile "catalog.labels" $ unlines $ [show n ++"\t"++l | (n,l) <- zip [1..length ps] (map snd ps)]

mouse def _ a b c d = def a b c d

------------------------------------------------------

getProtos feat = do
    opt <- getRawOption "--catalog"
    case opt of
        Nothing -> return []
        Just catalog -> do
            readCatalog (catalog++".avi") (mpSize 20) (catalog++".labels") Nothing feat

------------------------------------------------------

report protos = [(la ++ " - " ++ lb, n2 u v) | ((_,u),la) <- protos, ((_,v),lb) <- protos, la /= lb]