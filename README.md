# Vary: friendly and fast Variant types for Haskell

Just like tuples are a version of a user-defined product type (only without the field names), a Variant is a version of a user-defined sum type (but without the field names).

Variant types are the generalization of `Either`. Especially in the situation where you want to handle multiple errors, Variant types are a great abstraction to use.

Variant types are sometimes called '_polymorphic_ variants' for disambiguation. They are also commonly known as (open) unions, coproducts or extensible sums.

## General Usage

The modules in this library are intended to be used qualified:

```haskell ignore
import Vary (Vary, (:|))
import qualified Vary

import Vary.VEither (VEither(VLeft, VRight))
import qualified Vary.VEither as VEither
```

The library is intended to be used with the following extensions active:

```haskell top:0
{-# LANGUAGE GHC2021 #-} -- Of these, Vary uses: TypeApplications, TypeOperators, FlexibleContexts
{-# LANGUAGE DataKinds #-}
```



## Motivating Example

 Say we are writing an image thumbnailing service.

 * Given an image URL
 * We attempt to download it.
     * This can fail, because the URL is incorrect;
     * Or the URL /is/ correct but the server could not be reached (in which case we want to re-try later);
     * Or the server /could/ be reached, but downloading took longer than a set time limit.

 * We pass it to a thumbnailing program.
     * This can fail, because the downloaded file might turn out actually not to be a valid image file (PNG or JPG);
     * Or even if the downloaded file /is/ an image, it might have a much too high resolution to attempt to read;


 The first instinct of many Haskell programmers is to write dedicated sum types for these errors like so:

```haskell
data Image = Image
  deriving (Eq, Show)

data DownloaderError1
    = IncorrectUrl1
    | ServerUnreachable1
    | DownloadingTimedOut1 
  deriving (Eq, Ord, Show)

data ThumbnailError1
    = NotAnImage1
    | TooBigImage1
  deriving (Eq, Ord, Show)

download1 :: String -> Either DownloaderError1 Image
download1 url = 
    -- Pretend we're doing hard work here
    Right Image

thumbnail1 :: Image -> Either ThumbnailError1 Image
thumbnail1 image = 
    -- Pretend we're huffing and puffing
    Right Image
```

But if we try to plainly combine these two functions, we get a compiler error:

```haskell
thumbnailService1 url = do
    image <- download1 url
    thumbnail <- thumbnail1 image
    pure thumbnail
```

```
error:
    • Couldn't match type ‘ThumbnailError’ with ‘DownloaderError’
      Expected: Either DownloaderError Image
        Actual: Either ThumbnailError Image
```


We could \'solve\' this problem by adding yet another manual error type:

```haskell
data ThumbnailServiceError1
    = DownloaderError1 DownloaderError1
    | ThumbnailError1 ThumbnailError1
      deriving (Eq, Ord, Show)

thumbnailService2 :: String -> Either ThumbnailServiceError1 Image
thumbnailService2 url = do
    image <- first DownloaderError1 $ download1 url
    thumb <- first ThumbnailError1 $ thumbnail1 image
    pure thumb
```


This 'works', although already we can see that we're doing a lot of manual ceremony to pass the errors around.

And wait! We wanted to re-try in the case of a `ServerUnreachable` error!

```haskell
waitAndRetry = undefined :: Word -> (() -> a)  -> a

thumbnailServiceRetry2 :: String -> Either ThumbnailServiceError1 Image
thumbnailServiceRetry2 url = 
  case download1 url of
    Left ServerUnreachable1 -> waitAndRetry 10 (\_ -> thumbnailServiceRetry2 url) 
    Left other -> Left (DownloaderError1 other)
    Right image -> do
      thumb <- first ThumbnailError1 $ thumbnail1 image
      pure thumb
```

We now see:

- Even inside `thumbnailService` there now is quite a bit of ceremony 
  w.r.t. wrapping,unwrapping and mapping between error types.
- Callers will be asked to pattern match on the @ServerUnreachable@ error case,
  even though that case will already be handled inside the `thumbnailService` function itself!
- Imagine what happens when using this small function in a bigger system with many more errors!
  Do you keep defining more and more wrapper types for various combinations of errors?

#### There is a better way!

With the `Vary` and related `Vary.VEither.VEither` types, you can mix and match individual errors (or other types) at the places they are used.

- No more wrapper type definitions!
- Handing an error makes it disappear from the output type!

```haskell top:2
import Vary (Vary, (:|))
import qualified Vary
import Vary.VEither (VEither(..))
import qualified Vary.VEither as VEither
```
```haskell
data IncorrectUrl2 = IncorrectUrl2 deriving (Eq, Ord, Show)
data ServerUnreachable2 = ServerUnreachable2 deriving (Eq, Ord, Show)
data DownloadingTimedOut2 = DownloadingTimedOut2 deriving (Eq, Ord, Show)

data NotAnImage2 = NotAnImage2 deriving (Eq, Ord, Show)
data TooBigImage2 = TooBigImage2 deriving (Eq, Ord, Show)

download :: (ServerUnreachable2 :| err, IncorrectUrl2 :| err) => String -> VEither err Image
download url = 
    -- Pretend a lot of network communication happens here
    VRight Image

thumbnail :: (NotAnImage2 :| err, TooBigImage2 :| err) => Image -> VEither err Image
thumbnail image = 
    -- Pretend this is super hard
    VRight Image
```

Here is the version without the retry:

```haskell
thumbnailService :: String -> VEither [ServerUnreachable2, IncorrectUrl2, NotAnImage2, TooBigImage2] Image
thumbnailService url = do
  image <- download url
  thumb <- thumbnail image
  pure thumb
```

And here is all that needed to change to have a retry:

```haskell
thumbnailServiceRetry :: String -> VEither [IncorrectUrl2, NotAnImage2, TooBigImage2] Image
thumbnailServiceRetry url = do
  image <- download url 
           & VEither.onLeft (\ServerUnreachable2 -> waitAndRetry 10 (\_ -> thumbnailServiceRetry url)) id
  thumb <- thumbnail image
  pure thumb
```

## Why anoher Variant library?

I am aware of the following Haskell libraries offering support for Variant types already:

- [vinyl](https://hackage.haskell.org/package/vinyl)
- [extensible](https://hackage.haskell.org/package/extensible)
- [freer](https://hackage.haskell.org/package/freer)
- [fastsum](https://hackage.haskell.org/package/fastsum)
- [union](https://hackage.haskell.org/package/union)
- [open-union](https://hackage.haskell.org/package/open-union)
- [world-peace](https://hackage.haskell.org/package/world-peace)
- [haskus-utils-variant](https://hackage.haskell.org/package/haskus-utils-variant)

Vary improves upon them in the following ways:

- Function names in these libraries are long and repetitive, and often seem to be very different from names used elsewhere in `base` or the community.
  - `Vary` is intended to be used `qualified`, making the function names short and snappy, and allowing re-use of names like `map`, `from`, `on` and `into`.
- Many libraries define their variant type using a [Higher Kinded Data](https://reasonablypolymorphic.com/blog/higher-kinded-data/) pattern. This is really flexible, but not easy on the eyes.
  - `Vary`'s type is readable, which is what you want for the common case of using them for error handling.
  - It also means less manual type signatures are needed :-).
- Many libraries (exceptions: `fastsum`, `haskus`) define their variant as a GADT-style linked-list-like datatype. The advantage is that you need no `unsafeCoerce` anywhere. The disadvantage is that this has a huge runtime overhead.
  - `Vary` uses a single (unwrapped, strict) Word for the tag. GHC is able to optimize this representation very well!
  - Conversion between different variant shapes are also constant-time, as only this tag number needs to change.
- With the exception of `world-peace` and `haskus`, documentation of the libraries is very sparse.
  - All of the functions in `Vary` are documented and almost all of them have examples.
- The libraries try to make their variant be 'everything it can possibly be' and provide not only functions to work with variants by type, but also by index, popping, pushing, concatenating, handling all cases using a tuple of functions, etc. This makes it hard for a newcomer to understand what to use when.
  - `Vary` intentionally only exposes functions to work _by type_.
  - There is _one_ way to do case analysis of a `Vary`, namely using `Vary.on`. Only one thing to remember!
  - Many shape-modification functions were combined inside `Vary.morph`, so you only ever need that one!
  - Only the most widely-useful functions are provided in `Vary` itself. There are some extra functions in `Vary.Utils` which are intentionally left out of the main module to make it more digestible for new users. 
- Libraries are already many years old (with no newer updates), and so they are not using any of the newer GHC extensions or inference improvements.
  - `Vary` makes great use of the `GHC2021` group of extensions, TypeFamilies and the `TypeError` construct to make most type errors disappear and for the few that remain it should be easy to understand how to fix them.

## Acknowledgements

This library stands on the shoulders of giants.

In big part it was inspired by the great Variant abstraction [which exists in PureScript](https://pursuit.purescript.org/packages/purescript-variant/8.0.0) (and related [VEither](https://pursuit.purescript.org/packages/purescript-veither/1.0.5)).

Where PureScript has a leg up over Haskell is in its support of row types. To make the types nice to use in Haskell even lacking row typing support was a puzzle in which the [Effectful](https://github.com/haskell-effectful/effectful) library gave great inspiration (and some type-level trickery was copied essentially verbatim from there.)

Finally, a huge shoutout to the pre-existing Variant libraries in Haskell. Especially to [haskus-utils-variant](https://hackage.haskell.org/package/haskus-utils-variant) and [world-peace](https://hackage.haskell.org/package/world-peace) and the resources found in [this blog post](https://functor.tokyo/blog/2019-07-11-announcing-world-peace) by world-peace's author.


<!-- 
The following is executed by the README test runner,
but we don't want it to be visible to human readers:

```haskell top:1
{-# OPTIONS_GHC -fdefer-type-errors #-} -- We want to show some incorrect examples!
module Main where

import Test.Hspec (hspec, describe, it, shouldBe)
import Test.ShouldNotTypecheck (shouldNotTypecheck)
import Data.Bifunctor (first)
import Data.Function ((&))

```

```haskell
main :: IO ()
main = hspec $ do
  describe "motivating example" $ do
    describe "bad v1" $ do
      it "should not typecheck" $
        shouldNotTypecheck (thumbnailService1)
    describe "bad v2" $ do
      it "should work (but be verbose)" $
        thumbnailService2 "http://example.com" `shouldBe` (Right Image)
    describe "bad v2 (wth retry)" $ do
      it "should work (but be super verbose)" $
        thumbnailServiceRetry2 "http://example.com" `shouldBe` (Right Image)
    describe "nice" $ do
      it "should work nicely" $
        thumbnailService "http://example.com" `shouldBe` (VRight Image)
    describe "nice (with retry)" $ do
      it "should work nicely" $
        thumbnailServiceRetry "http://example.com" `shouldBe` (VRight Image)
```
-->
