{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE ScopedTypeVariables   #-}

module Control.Effect.TestSupport(
    TestInput(..)
  , emptyTestInput
  , TestOutput(..)
  , emptyTestOutput
  , TestState(..)
  , emptyTestState
  , runEffects
) where

import           Control.Effect
import           Control.Effect.Stub

import           Control.Monad.Reader
import           Control.Monad.Writer
import           Data.Maybe
import           Data.Monoid

import           Control.Exception.Safe
import           Data.ByteString        (ByteString)
import qualified Data.ByteString        as ByteString hiding (unpack)
import           Data.HashMap.Strict    (HashMap)
import qualified Data.HashMap.Strict    as HashMap
import           Data.Hourglass         (Elapsed, Seconds, toSeconds)
import           Data.Text              (Text)
import           System.Environment
import           Test.Hspec

emptyTestState :: TestState
emptyTestState = TestState {
    fileSystem = HashMap.empty
  , elapsed = 0
  , events = HashMap.empty
}

data TestState = TestState {
    fileSystem :: HashMap Text ByteString
  , elapsed    :: Elapsed
  , events     :: HashMap Elapsed [TestState -> TestState]
}

instance HasFiles TestState where
  asFiles = fileSystem

instance HasTime TestState where
  asTime = elapsed
  updateTime s elapsed = s {
    elapsed = elapsed
  }

instance HasTimeline TestState where
  asTimeline = events
  updateTimeline s events = s {
    events = events
  }

emptyTestInput = TestInput {
    args = []
  , stdinContent = ""
}

data TestInput = TestInput {
    args         :: [Text]
  , stdinContent :: ByteString
} deriving (Eq, Show)

instance HasArguments TestInput where
  asArguments = args

instance HasStdin TestInput where
  asStdin = stdinContent

emptyTestOutput = TestOutput {
    stdout = ""
  , stderr = ""
  , waitCount = []
}

data TestOutput = TestOutput {
    stdout    :: ByteString
  , stderr    :: ByteString
  , waitCount :: [Seconds]
} deriving (Eq, Show)

instance Monoid TestOutput where
  mempty = emptyTestOutput
  mappend left right = emptyTestOutput {
      stdout = stdout left <> stdout right
    , stderr = stderr left <> stderr right
    , waitCount = waitCount left <> waitCount right
  }

instance HasStdout TestOutput where
  asStdout out = emptyTestOutput {
    stdout = out
  }

instance HasStderr TestOutput where
  asStderr err = emptyTestOutput {
    stderr = err
  }

instance HasWaitCount TestOutput where
  asWaitCount n = emptyTestOutput {
    waitCount = [toSeconds n]
  }

type Effects a = (forall m. (Wait m, Time m, MonadIO m) => m a)
runEffects :: Effects a -> IO a
runEffects f = do
  real <- read . fromMaybe "False" <$> lookupEnv "REAL_IO"
  if real then
      f
    else do
      (result, _, _::TestOutput) <- runStubT emptyTestInput emptyTestState f
      pure result
