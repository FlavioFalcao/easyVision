{-# OPTIONS -fffi #-}

module Ipp where

import Foreign
import Control.Monad(when)
 
--import GSL hiding(rows, cols) 

------------------------------------------------------------
------------- descriptor of an ipp image -------------------

data Img = Img { fptr :: ForeignPtr ()
               , ptr  :: Ptr ()
               , step :: Int
               , datasize :: Int
               , layers :: Int
               , rows :: Int
               , cols :: Int
               }

-- this is the constructor, given pixel size, layers, rows and columns
-- we use the Haskell gc instead of ippiMalloc and ippiFree

img sz ly r c = do
    let w = c*sz*ly
    let rest = w `mod` 32
    let c' = if rest == 0 then w else w + 32 - rest
    fp <- mallocForeignPtrBytes (r*c'+31)
    let p' = unsafeForeignPtrToPtr fp
    let p = alignPtr p' 32
    --print (p', p) -- debug
    return Img { rows = r
               , cols = c
               , layers = ly
               , datasize = sz
               , fptr = fp
               , ptr = p
               , step = c' 
               }
                
getData :: Img -> IO [[Float]]
getData (Img {fptr = fp, ptr = p, datasize = d, step = s, rows = r, cols = c}) = do
    let jump = s `quot` d
    let row k = peekArray c (advancePtr (castPtr p) (k*jump))
    r <- mapM row [0 .. r-1]
    touchForeignPtr fp
    return r


data ROI = ROI { r1, r2, c1, c2 :: Int}

starting :: Img -> ROI -> Ptr ()
starting img roi = plusPtr (ptr img) (r1 roi * step img + c1 roi*(datasize img)*(layers img))
  
roiSize (ROI { r1=a, r2=b, c1=x, c2=y}) = encodeAsDouble  (y-x+1)  (b-a+1)

encodeAsDouble :: Int -> Int -> Double
encodeAsDouble a b = unsafePerformIO $ do
    p <- mallocArray 2
    pokeArray p [a,b]
    r <- peek (castPtr p)
    free p
    return r

fullroi img = ROI {r1=0, r2=rows img-1, c1=0, c2=cols img-1}

shrink (r,c) roi = 
    ROI {r1=(r1 roi) +r, 
         r2=(r2 roi) -r,
         c1=(c1 roi) +c,
         c2=(c2 roi) -c}


mK1 f roi img = do
    err <- f (starting img roi) (step img) (roiSize roi)
    when (err/=0) (error "ipp mK1")
    touchForeignPtr (fptr img)
    return ()
    
mK2 f roi img other = do
    err <- f (starting other roi) (step other) (starting img roi) (step img) (roiSize roi)
    when (err/=0) (error "ipp mK2")
    touchForeignPtr (fptr img)
    touchForeignPtr (fptr other)
    return ()        
    
mK3 f roi img other1 other2 = do
    err <- f (starting other1 roi) (step other1) (starting other2 roi) (step other2) (starting img roi) (step img) (roiSize roi)
    when (err/=0) (error "ipp mK3")
    touchForeignPtr (fptr img)
    touchForeignPtr (fptr other1)
    touchForeignPtr (fptr other1)
    return ()        
    
mK3p1 f p roi img other1 other2 = do
    err <- f (starting other1 roi) (step other1) (starting other2 roi) (step other2) (starting img roi) (step img) (roiSize roi) p
    when (err/=0) (error "ipp mK3p1")
    touchForeignPtr (fptr img)
    touchForeignPtr (fptr other1)
    touchForeignPtr (fptr other1)
    return ()        
    
    
mK1p1 f p roi img = do
    err <- f (starting img roi) (step img) (roiSize roi) p
    when (err/=0) (error "ipp mK1p1")
    touchForeignPtr (fptr img)
    return () 
       
mK1p2 f p1 p2 roi img = do
    err <- f (starting img roi) (step img) (roiSize roi) p1 p2
    when (err/=0) (error "ipp mK1p2")
    touchForeignPtr (fptr img)
    return () 
       
       
mK2p1 f p roi img other = do
    err <- f (starting other roi) (step other) (starting img roi) (step img) (roiSize roi) p
    when (err/=0) (error "ipp mK2p1")
    touchForeignPtr (fptr img)
    touchForeignPtr (fptr other)
    return ()          

mK2p2 f p1 p2 roi img other = do
    err <- f (starting other roi) (step other) (starting img roi) (step img) (roiSize roi) p1 p2
    when (err/=0) (error "ipp mK2p2")
    touchForeignPtr (fptr img)
    touchForeignPtr (fptr other)
    return ()  
    
mK2p3 f p1 p2 p3 roi img other = do
    err <- f (starting other roi) (step other) (starting img roi) (step img) (roiSize roi) p1 p2 p3
    when (err/=0) (error "ipp mK2p3")
    touchForeignPtr (fptr img)
    touchForeignPtr (fptr other)
    return ()      
    
imgAs im = img (datasize im) (layers im) (rows im) (cols im)

src im roi f = f (starting im roi) (step im)
dst im roi f = f (starting im roi) (step im) (roiSize roi)
app p f = f p

checkIPP msg ls f = do
    err <- f
    when (err/=0) (error msg)
    mapM_ (touchForeignPtr . fptr) ls
    return ()

infixl 0 //
(//) = flip ($)