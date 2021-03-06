{-|
Module      : Qux.Command.Build
Description : Options and handler for the build subcommand.

Copyright   : (c) Henry J. Wylde, 2015
License     : BSD3
Maintainer  : hjwylde@gmail.com

Options and handler for the build subcommand.
-}

module Qux.Command.Build (
    -- * Options
    Options(..),
    defaultOptions,

    Format(..),

    -- * Handle
    handle,
) where

import Control.Monad.Except

import Data.Function
import Data.List.Extra

import Language.Qux.Annotated.Parser
import Language.Qux.Annotated.Syntax
import Language.Qux.Annotated.TypeChecker

import Prelude hiding (log)

import qualified Qux.BuildSteps as BuildSteps
import           Qux.Worker

-- | Build options.
data Options = Options
    { optCompile     :: Bool        -- ^ Flag for compiling to LLVM.
    , optDestination :: FilePath    -- ^ The destination folder to write the compiled files.
    , optFormat      :: Format      -- ^ The output format.
    , optLibdirs     :: [FilePath]  -- ^ Directories to search for extra library files to reference
                                    --   (but not to compile).
    , optTypeCheck   :: Bool        -- ^ Flag for type checking the files.
    , argFilePaths   :: [FilePath]  -- ^ The files to compile.
    } deriving (Eq, Show)

-- | The default build options.
defaultOptions :: Options
defaultOptions = Options
    { optCompile        = False
    , optDestination    = "."
    , optFormat         = Bitcode
    , optLibdirs        = []
    , optTypeCheck      = False
    , argFilePaths      = []
    }

-- | Output format for the compiled LLVM code.
data Format = Assembly | Bitcode
    deriving (Eq, Show)

-- | Builds the files according to the options.
handle :: Options -> WorkerT IO ()
handle options = do
    log Debug "Parsing programs ..."
    programs <- BuildSteps.parseAll $ argFilePaths options

    log Debug "Parsing libraries ..."
    libraries <- BuildSteps.parseAll =<< BuildSteps.expandLibdirs (optLibdirs options)

    build options programs libraries

build :: Options -> [Program SourcePos] -> [Program SourcePos] -> WorkerT IO ()
build options programs libraries = do
    log Debug "Applying sanity checker ..."
    BuildSteps.sanityCheckAll programs libraries

    log Debug "Applying name and type resolvers ..."
    programs' <- BuildSteps.resolveAll baseContext' programs

    when (optTypeCheck options) $ do
        log Debug "Applying type checker ..."
        BuildSteps.typeCheckAll baseContext' programs'

    when (optCompile options) $ do
        log Debug "Compiling programs ..."
        case format of
            Assembly    -> BuildSteps.compileAllToLlvmAssembly baseContext' binDir programs'
            Bitcode     -> BuildSteps.compileAllToLlvmBitcode baseContext' binDir programs'
    where
        baseContext' = baseContext $ map simp (programs ++ libraries)

        format = optFormat options
        binDir = optDestination options
