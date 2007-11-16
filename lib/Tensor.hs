{-# OPTIONS_GHC -fglasgow-exts #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Tensor
-- Copyright   :  (c) Alberto Ruiz 2007
-- License     :  GPL-style
--
-- Maintainer  :  Alberto Ruiz <aruiz@um.es>
-- Stability   :  provisional
-- Portability :  portable (uses FFI)
--
-- an experiment with tensors
--
-----------------------------------------------------------------------------


module Tensor (
    -- * Construction
    Tensor, tensor, scalar,
    -- * Manipulation
    IdxName, IdxType(..), IdxDesc(..), structure, dims, coords, parts,
    tridx, withIdx, raise,
    -- * Operations
    addT, mulT,
    -- * Exterior Algebra
    wedge, dual, leviCivita, innerLevi, innerAT, niceAS,
    -- * Misc
    liftTensor, liftTensor2
) where

import Data.Packed.Internal
import Foreign.Storable
import Data.List(sort,elemIndex,nub,foldl1',foldl')
import Numeric.LinearAlgebra hiding (rank)

data IdxType = Covariant | Contravariant deriving (Show,Eq)

type IdxName = String

data IdxDesc = IdxDesc { idxDim  :: Int,
                         idxType :: IdxType,
                         idxName :: IdxName } deriving Eq

instance Show IdxDesc where
    show (IdxDesc n t name) = name ++ sym t ++"["++show n++"]"
        where sym Covariant     = "_"
              sym Contravariant = "^"


data Tensor t = T { dims   :: [IdxDesc]
                  , ten    :: Vector t
                  }

-- | returns the coordinates of a tensor in row - major order
coords :: Tensor t -> Vector t
coords = ten

instance (Show a, Element a) => Show (Tensor a) where
    show T {dims = [], ten = t} = "scalar "++show (t `at` 0)
    show t = "("++shdims (dims t) ++") "++ showdt t

asMatrix t = reshape (idxDim $ dims t!!1) (ten t)

showdt t | rank t == 1 = show (toList (ten t))
         | rank t == 2 = ('\n':) . format "  " show $ asMatrix $ t
         | otherwise = concatMap showdt $ parts t (head (names t))

-- | a nice description of the tensor structure
shdims :: [IdxDesc] -> String
shdims [] = ""
shdims [d] = show d 
shdims (d:ds) = show d ++ "><"++ shdims ds

-- | tensor rank (number of indices)
rank :: Tensor t -> Int
rank = length . dims

names :: Tensor t -> [IdxName]
names t = map idxName (dims t)

-- | number of contravariant and covariant indices
structure :: Tensor t -> (Int,Int)
structure t = (rank t - n, n) where
    n = length $ filter isCov (dims t)
    isCov d = idxType d == Covariant

-- | creates a rank-zero tensor from a scalar
scalar :: Storable t => t -> Tensor t
scalar x = T [] (fromList [x])

-- | Creates a tensor from a signed list of dimensions (positive = contravariant, negative = covariant) and a Vector containing the coordinates in row major order.
tensor :: [Int] -> Vector a -> Tensor a
tensor dssig vec = T d v `withIdx` seqind where
    n = product (map abs dssig)
    v = if dim vec == n then vec else error "wrong arguments for tensor"
    d = map cr dssig
    cr n | n > 0 = IdxDesc {idxName = "", idxDim =  n, idxType = Contravariant}
         | n < 0 = IdxDesc {idxName = "", idxDim = -n, idxType = Covariant    }


tensorFromVector :: IdxType -> Vector t -> Tensor t
tensorFromVector tp v = T {dims = [IdxDesc (dim v) tp "1"], ten = v}

tensorFromMatrix :: Element t => IdxType -> IdxType -> Matrix t -> Tensor t
tensorFromMatrix tpr tpc m = T {dims = [IdxDesc (rows m) tpr "1",IdxDesc (cols m) tpc "2"]
                               , ten = flatten m}


liftTensor :: (Vector a -> Vector b) -> Tensor a -> Tensor b
liftTensor f (T d v) = T d (f v)

liftTensor2 :: (Vector a -> Vector b -> Vector c) -> Tensor a -> Tensor b -> Tensor c
liftTensor2 f (T d1 v1) (T d2 v2) | compat d1 d2 = T d1 (f v1 v2)
                                  | otherwise = error "liftTensor2 with incompatible tensors"
    where compat a b = length a == length b




-- | express the tensor as a matrix with the given index in columns
findIdx :: (Element t) => IdxName -> Tensor t
        -> (([IdxDesc], [IdxDesc]), Matrix t)
findIdx name t = ((d1,d2),m) where
    (d1,d2) = span (\d -> idxName d /= name) (dims t)
    c = product (map idxDim d2)
    m = matrixFromVector RowMajor c (ten t)

-- | express the tensor as a matrix with the given index in rows
putFirstIdx :: (Element t) => String -> Tensor t -> ([IdxDesc], Matrix t)
putFirstIdx name t = (nd,m')
    where ((d1,d2),m) = findIdx name t
          m' = matrixFromVector RowMajor c $ flatten $ trans m
          nd = d2++d1
          c = dim (ten t) `div` (idxDim $ head d2)


-- | renames all the indices in the current order (repeated indices may get different names)
withIdx :: Tensor t -> [IdxName] -> Tensor t
withIdx (T d v) l = T d' v
    where d' = zipWith f d l
          f i n = i {idxName=n}


-- | raises or lowers all the indices of a tensor (with euclidean metric)
raise :: Tensor t -> Tensor t
raise (T d v) = T (map raise' d) v
    where raise' idx@IdxDesc {idxType = Covariant } = idx {idxType = Contravariant}
          raise' idx@IdxDesc {idxType = Contravariant } = idx {idxType = Covariant}


-- | index transposition to a desired order. You can specify only a subset of the indices, which will be moved to the front of indices list
tridx :: (Element t) => [IdxName] -> Tensor t -> Tensor t
tridx [] t = t
tridx (name:rest) t = T (d:ds) (join ts) where
    ((_,d:_),_) = findIdx name t
    ps = map (tridx rest) (parts t name)
    ts = map ten ps
    ds = dims (head ps)



-- | extracts a given part of a tensor
part :: (Element t) => Tensor t -> (IdxName, Int) -> Tensor t
part t (name,k) = if k<0 || k>=l
                    then error $ "part "++show (name,k)++" out of range" -- in "++show t
                    else T {dims = ds, ten = toRows m !! k}
    where (d:ds,m) = putFirstIdx name t
          l = idxDim d

-- | creates a list with all parts of a tensor along a given index
parts :: (Element t) => Tensor t -> IdxName -> [Tensor t]
parts t name = map f (toRows m)
    where (d:ds,m) = putFirstIdx name t
          l = idxDim d
          f t = T {dims=ds, ten=t}


compatIdx :: (Element t1, Element t) => Tensor t1 -> IdxName -> Tensor t -> IdxName -> Bool
compatIdx t1 n1 t2 n2 = compatIdxAux d1 d2 where
    d1 = head $ snd $ fst $ findIdx n1 t1
    d2 = head $ snd $ fst $ findIdx n2 t2
    compatIdxAux IdxDesc {idxDim = n1, idxType = t1}
                 IdxDesc {idxDim = n2, idxType = t2}
        = t1 /= t2 && n1 == n2


outer' u v = flatten (outer u v)

-- | tensor product without without any contractions
rawProduct :: (Element t, Num t) => Tensor t -> Tensor t -> Tensor t
rawProduct (T d1 v1) (T d2 v2) = T (d1++d2) (outer' v1 v2)

-- | contraction of the product of two tensors 
contraction2 :: (Element t, Num t) => Tensor t -> IdxName -> Tensor t -> IdxName -> Tensor t
contraction2 t1 n1 t2 n2 =
    if compatIdx t1 n1 t2 n2
        then T (tail d1 ++ tail d2) (flatten m)
        else error "wrong contraction2"
  where (d1,m1) = putFirstIdx n1 t1
        (d2,m2) = putFirstIdx n2 t2
        m = multiply (trans m1) m2

-- | contraction of a tensor along two given indices
contraction1 :: (Linear Vector t) => Tensor t -> IdxName -> IdxName -> Tensor t
contraction1 t name1 name2 =
    if compatIdx t name1 t name2
        then sumT y
        else error $ "wrong contraction1: "++(shdims$dims$t)++" "++name1++" "++name2
    where d = dims (head y)
          x = (map (flip parts name2) (parts t name1))
          y = map head $ zipWith drop [0..] x

-- | contraction of a tensor along a repeated index
contraction1c :: (Linear Vector t) => Tensor t -> IdxName -> Tensor t
contraction1c t n = contraction1 renamed n' n
    where n' = n++"'" -- hmmm
          renamed = withIdx t auxnames
          auxnames = h ++ (n':r)
          (h,_:r) = break (==n) (map idxName (dims t))

-- | alternative and inefficient version of contraction2
contraction2' :: (Linear Vector t) => Tensor t -> IdxName -> Tensor t -> IdxName -> Tensor t
contraction2' t1 n1 t2 n2 =
    if compatIdx t1 n1 t2 n2
        then contraction1 (rawProduct t1 t2) n1 n2
        else error "wrong contraction'"

-- | applies a sequence of contractions
contractions :: (Linear Vector t) => Tensor t -> [(IdxName, IdxName)] -> Tensor t
contractions t pairs = foldl' contract1b t pairs
    where contract1b t (n1,n2) = contraction1 t n1 n2

-- | applies a sequence of contractions of same index
contractionsC :: (Linear Vector t) => Tensor t -> [IdxName] -> Tensor t
contractionsC t is = foldl' contraction1c t is


-- | applies a contraction on the first indices of the tensors
contractionF :: (Linear Vector t) => Tensor t -> Tensor t -> Tensor t
contractionF t1 t2 = contraction2 t1 n1 t2 n2
    where n1 = fn t1
          n2 = fn t2
          fn = idxName . head . dims

-- | computes all compatible contractions of the product of two tensors that would arise if the index names were equal
possibleContractions :: (Linear Vector t) => Tensor t -> Tensor t -> [Tensor t]
possibleContractions t1 t2 = [ contraction2 t1 n1 t2 n2 | n1 <- names t1, n2 <- names t2, compatIdx t1 n1 t2 n2 ]



desiredContractions2 :: Tensor t -> Tensor t1 -> [(IdxName, IdxName)]
desiredContractions2 t1 t2 = [ (n1,n2) | n1 <- names t1, n2 <- names t2, n1==n2]

desiredContractions1 :: Tensor t -> [IdxName]
desiredContractions1 t = [ n1 | (a,n1) <- x , (b,n2) <- x, a/=b, n1==n2]
    where x = zip [0..] (names t)

-- | tensor product with the convention that repeated indices are contracted.
mulT :: (Linear Vector t) => Tensor t -> Tensor t -> Tensor t
mulT t1 t2 = r where
    t1r = contractionsC t1 (desiredContractions1 t1)
    t2r = contractionsC t2 (desiredContractions1 t2)
    cs = desiredContractions2 t1r t2r
    r = case cs of
        [] -> rawProduct t1r t2r
        (n1,n2):as -> contractionsC (contraction2 t1r n1 t2r n2) (map fst as)

-----------------------------------------------------------------

-- | tensor addition (for tensors with the same structure)
addT :: (Linear Vector a) => Tensor a -> Tensor a -> Tensor a
addT a b = liftTensor2 add a b

sumT :: (Linear Vector a) => [Tensor a] -> Tensor a
sumT l = foldl1' addT l

-----------------------------------------------------------------

-- sent to Haskell-Cafe by Sebastian Sylvan
perms :: [t] -> [[t]]
perms [x] = [[x]]
perms xs = [y:ps | (y,ys) <- selections xs , ps <- perms ys]
    where
        selections []     = []
        selections (x:xs) = (x,xs) : [(y,x:ys) | (y,ys) <- selections xs]

interchanges :: (Ord a) => [a] -> Int
interchanges ls = sum (map (count ls) ls)
    where count l p = length $ filter (>p) $ take pel l
              where Just pel = elemIndex p l

signature :: (Num t, Ord a) => [a] -> t
signature l | length (nub l) < length l =  0
            | even (interchanges l)     =  1
            | otherwise                 = -1


sym :: (Linear Vector t) => Tensor t -> Tensor t
sym t = T (dims t) (ten (sym' (withIdx t seqind)))
    where sym' t = sumT $ map (flip tridx t) (perms (names t))
              where nms = map idxName . dims

antisym :: (Linear Vector t) => Tensor t -> Tensor t
antisym t = T (dims t) (ten (antisym' (withIdx t seqind)))
    where antisym' t = sumT $ map (scsig . flip tridx t) (perms (names t))
          scsig t = scalar (signature (nms t)) `rawProduct` t
              where nms = map idxName . dims

-- | the wedge product of two tensors (implemented as the antisymmetrization of the ordinary tensor product).
wedge :: (Linear Vector t, Fractional t) => Tensor t -> Tensor t -> Tensor t
wedge a b = antisym (rawProduct (norper a) (norper b))
    where norper t = rawProduct t (scalar (recip $ fromIntegral $ fact (rank t)))

-- antinorper t = rawProduct t (scalar (fromIntegral $ fact (rank t)))

-- | The euclidean inner product of two completely antisymmetric tensors
innerAT :: (Fractional t, Element t) => Tensor t -> Tensor t -> t
innerAT t1 t2 = dot (ten t1) (ten t2) / fromIntegral (fact $ rank t1)

fact :: (Num t, Enum t) => t -> t
fact n = product [1..n]

seqind' :: [[String]]
seqind' = map return seqind

seqind :: [String]
seqind = map show [1..]

-- | completely antisymmetric covariant tensor of dimension n
leviCivita :: (Linear Vector t) => Int -> Tensor t
leviCivita n = antisym $ foldl1 rawProduct $ zipWith withIdx auxbase seqind'
    where auxbase = map tc (toRows (ident n))
          tc = tensorFromVector Covariant
          ident n = diag $ fromList $ replicate n 1

-- | contraction of leviCivita with a list of vectors (and raise with euclidean metric)
innerLevi :: (Linear Vector t) => [Tensor t] -> Tensor t
innerLevi vs = raise $ foldl' contractionF (leviCivita n) vs
    where n = idxDim . head . dims . head $ vs


-- | obtains the dual of a multivector (with euclidean metric)
dual :: (Linear Vector t, Fractional t) => Tensor t -> Tensor t
dual t = raise $ leviCivita n `mulT` withIdx t seqind `rawProduct` x
    where n = idxDim . head . dims $ t
          x = scalar (recip $ fromIntegral $ fact (rank t))


-- | shows only the relevant components of an antisymmetric tensor
niceAS :: (Element t, Fractional t) => Tensor t -> [(t, [Int])]
niceAS t = filter ((/=0.0).fst) $ zip vals base
    where vals = map ((`at` 0).ten.foldl' partF t) (map (map pred) base)
          base = asBase r n
          r = length (dims t)
          n = idxDim . head . dims $ t
          partF t i = part t (name,i) where name = idxName . head . dims $ t
          asBase r n = filter (\x-> (x==nub x && x==sort x)) $ sequence $ replicate r [1..n]