{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE BangPatterns,
                        ConstraintKinds,
                        DataKinds,
                        DeriveFunctor,
                        DeriveGeneric,
                        FlexibleContexts,
                        FlexibleInstances,
                        GADTs,
                        GeneralizedNewtypeDeriving,
                        LambdaCase,
                        MultiParamTypeClasses,
                        NoStarIsType,
                        RankNTypes,
                        RoleAnnotations,
                        ScopedTypeVariables,
                        StandaloneDeriving,
                        TupleSections,
                        TypeApplications,
                        TypeFamilies,
                        TypeOperators,
    PolyKinds,
    UndecidableInstances,
    AllowAmbiguousTypes
                        #-}

--{-# OPTIONS_HADDOCK not-home #-}
module Vary.Utils where

import Data.Kind
import Data.Proxy
import GHC.TypeLits

-- class e :|| es where
type (:|) e es = Member e es

-- instance (e :| es, Member e es) => e :|| es where

-- class (e :: Type) :| (es :: [Type]) where
--   -- | Get the position of @e@ in @es@.
--   --
--   -- /Note:/ GHC is kind enough to cache these values as they're top level CAFs,
--   -- so the lookup is amortized @O(1)@ without any language level tricks.
--   reifyIndex :: Int
--   reifyIndex =
--     -- Don't show "minimal complete definition" in haddock.
--     error "reifyIndex"

-- instance TypeError
--   ( Text "There is no alternative for '" :<>: ShowType e :<>: Text "' in the variant list"
--   ) => e :| '[] where
--   reifyIndex = error "unreachable"

-- instance {-# OVERLAPPING #-} e :| (e : es) where
--   reifyIndex = 0

-- instance e :| es => e :| (x : es) where
--   reifyIndex = 1 + reifyIndex @e @es


-- | Provide evidence that @xs@ is a subset of @es@.
class KnownPrefix es => Subset (xs :: [Type]) (es :: [Type]) where
  subsetFullyKnown :: Bool
  subsetFullyKnown =
    -- Don't show "minimal complete definition" in haddock.
    error "subsetFullyKnown"

  reifyIndices :: [Int]
  reifyIndices =
    -- Don't show "minimal complete definition" in haddock.
    error "reifyIndices"

-- If the subset is not fully known, make sure the subset and the base stack
-- have the same unknown suffix.
instance {-# INCOHERENT #-}
  ( KnownPrefix es
  , xs `IsUnknownSuffixOf` es
  ) => Subset xs es where
  subsetFullyKnown = False
  reifyIndices = []

-- If the subset is fully known, we're done.
instance KnownPrefix es => Subset '[] es where
  subsetFullyKnown = True
  reifyIndices = []

instance (e :| es, Subset xs es) => Subset (e : xs) es where
  subsetFullyKnown = subsetFullyKnown @xs @es
  reifyIndices = natValue @(IndexOf e es) : reifyIndices @xs @es

----

-- | Calculate length of a statically known prefix of @es@.
class KnownPrefix (es :: [Type]) where
  prefixLength :: Int

instance KnownPrefix es => KnownPrefix (e : es) where
  prefixLength = 1 + prefixLength @es

instance {-# INCOHERENT #-} KnownPrefix es where
  prefixLength = 0

----

-- | Require that @xs@ is the unknown suffix of @es@.
class (xs :: [Type]) `IsUnknownSuffixOf` (es :: [Type])
instance {-# INCOHERENT #-} xs ~ es => xs `IsUnknownSuffixOf` es
instance xs `IsUnknownSuffixOf` es => xs `IsUnknownSuffixOf` (e : es)



-- | Get list length
type family Length (xs :: [k]) :: Nat where
   Length xs = Length' 0 xs

type family Length' n (xs :: [k]) :: Nat where
   Length' n '[]       = n
   Length' n (x ': xs) = Length' (n+1) xs

natValue :: forall (n :: Nat) a. (KnownNat n, Num a) => a
{-# INLINABLE natValue #-}
natValue = fromIntegral (natVal (Proxy :: Proxy n))

-- | Get a Nat value as a Word
natValue' :: forall (n :: Nat). KnownNat n => Word
{-# INLINABLE natValue' #-}
natValue' = natValue @n

-- | Get the first index of a type
type IndexOf (x :: k) (xs :: [k]) = IndexOf' (MaybeIndexOf x xs) x xs

-- | Get the first index of a type
type family IndexOf' (i :: Nat) (a :: k) (l :: [k]) :: Nat where
   IndexOf' 0 x l = TypeError ( 'ShowType x
                          ':<>: 'Text " not found in list:"
                          ':$$: 'Text " "
                          ':<>: 'ShowType l )
   IndexOf' i _ _ = i - 1

-- | Get the first index (starting from 1) of a type or 0 if none
type family MaybeIndexOf (a :: k) (l :: [k]) where
   MaybeIndexOf x xs = MaybeIndexOf' 0 x xs

-- | Helper for MaybeIndexOf
type family MaybeIndexOf' (n :: Nat) (a :: k) (l :: [k]) where
   MaybeIndexOf' n x '[]       = 0
   MaybeIndexOf' n x (x ': xs) = n + 1
   MaybeIndexOf' n x (y ': xs) = MaybeIndexOf' (n+1) x xs


-- | Indexed access into the list
type Index (n :: Nat) (l :: [k]) = Index' n l l

-- | Indexed access into the list
type family Index' (n :: Nat) (l :: [k]) (l2 :: [k]) :: k where
   Index' 0 (x ': _ ) _  = x
   Index' n (_ ': xs) l2 = Index' (n-1) xs l2
   Index' n '[]       l2 = TypeError ( 'Text "Index "
                                ':<>: 'ShowType n
                                ':<>: 'Text " out of bounds for list:"
                                ':$$: 'Text " "
                                ':<>: 'ShowType l2 )

-- | Constraint: x member of xs
type family Member x xs :: Constraint where
   Member x xs = MemberAtIndex (IndexOf x xs) x xs
   
type MemberAtIndex i x xs =
   ( x ~ Index i xs
   , KnownNat i
   )