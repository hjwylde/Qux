
{-# OPTIONS_HADDOCK hide, prune #-}

{-|
Module      : Qux.Commands

Copyright   : (c) Henry J. Wylde, 2015
License     : BSD3
Maintainer  : public@hjwylde.com
-}

module Qux.Commands where

import Data.Version (showVersion)

import              Language.Qux.Annotated.PrettyPrinter
import qualified    Language.Qux.Version                    as Qux

import Options.Applicative
import Options.Applicative.Types

import Prelude hiding (print)

import qualified Qux.Commands.Build     as Build
import qualified Qux.Commands.Check     as Check
import qualified Qux.Commands.Compile   as Compile
import qualified Qux.Commands.Print     as Print
import qualified Qux.Commands.Run       as Run
import qualified Qux.Version            as Binary


-- * Optparse for Qux

quxPrefs :: ParserPrefs
quxPrefs = prefs $ columns 100

quxInfo :: ParserInfo Options
quxInfo = info (infoOptions <*> qux) (fullDesc <> noIntersperse)
    where
        infoOptions = helper <*> version <*> numericVersion <*> quxVersion
        version = infoOption ("Version " ++ showVersion Binary.version) $ mconcat [
            long "version", short 'V', hidden,
            help "Show this binary's version"
            ]
        numericVersion = infoOption (showVersion Binary.version) $ mconcat [
            long "numeric-version", hidden,
            help "Show this binary's version (without the prefix)"
            ]
        quxVersion = infoOption ("Qux version " ++ showVersion Qux.version) $ mconcat [
            long "qux-version", hidden,
            help "Show the qux version this binary was compiled with"
            ]

-- * Command

data Options = Options {
    argCommand :: Command
    }

qux :: Parser Options
qux = Options <$> subparser (mconcat [
    command "build"     $ info (helper <*> build)   (fullDesc <> progDesc "Build FILES using composable options"),
    command "check"     $ info (helper <*> check)   (fullDesc <> progDesc "Check FILES for correctness" <> header "Shortcut for `qux build --type-check'"),
    command "compile"   $ info (helper <*> compile) (fullDesc <> progDesc "Compile FILES into the LLVM IR" <> header "Shortcut for `qux build --compile'"),
    command "print"     $ info (helper <*> print)   (fullDesc <> progDesc "Pretty print FILE"),
    command "run"       $ info (helper <*> run)     (fullDesc <> progDesc "Run FILE passing in ARGS as program arguments")
    ])


-- * Subcommands

data Command    = Build     Build.Options
                | Check     Check.Options
                | Compile   Compile.Options
                | Print     Print.Options
                | Run       Run.Options


-- ** Build

build :: Parser Command
build = fmap Build $ Build.Options
    <$> switch (mconcat [
        long "compile", short 'c',
        help "Enable compilation to LLVM IR"
        ])
    <*> strOption (mconcat [
        long "destination", short 'd', metavar "DIR",
        value "./", showDefault,
        help "Specify the output directory to put the compiled LLVM IR"
        ])
    <*> formatOption (mconcat [
        long "format", short 'f', metavar "FORMAT",
        value Build.Bitcode, showDefault,
        help "Specify the LLVM output format as either `bitcode' or `assembly'"
        ])
    <*> switch (mconcat [
        long "type-check",
        help "Enable type checking"
        ])
    <*> some (strArgument $ mconcat [
        metavar "FILES..."
        ])


-- ** Check

check :: Parser Command
check = Check . Check.Options <$> some (strArgument $ mconcat [
    metavar "FILES..."
    ])


-- ** Compile

compile :: Parser Command
compile = fmap Compile $ Compile.Options
    <$> strOption (mconcat [
        long "destination", short 'd', metavar "DIR",
        value "./", showDefault,
        help "Specify the output directory to put the compiled LLVM IR"
        ])
    <*> formatOption (mconcat [
        long "format", short 'f', metavar "FORMAT",
        value Build.Bitcode, showDefault,
        help "Specify the LLVM output format as either `bitcode' or `assembly'"
        ])
    <*> some (strArgument $ mconcat [
        metavar "FILES..."
    ])


-- ** Print

print :: Parser Command
print = fmap Print $ Print.Options
    <$> option auto (mconcat [
        long "line-length", short 'l', metavar "LENGTH",
        value 100, showDefault,
        help "Specify the maximum line length"
        ])
    <*> modeOption (mconcat [
        long "mode", short 'm', metavar "MODE",
        value PageMode, showDefaultWith $ const "normal",
        help "Specify the rendering mode as either `normal' or `one-line'"
        ])
    <*> option auto (mconcat [
        long "ribbons-per-line", short 'r', metavar "RIBBONS",
        value 1.5, showDefault,
        help "Specify the ratio of line length to ribbon length"
        ])
    <*> strArgument (mconcat [
        metavar "FILE"
        ])
    where
        modeOption :: Mod OptionFields Mode -> Parser Mode
        modeOption = option $ do
            opt <- readerAsk

            case opt of
                "normal"    -> return PageMode
                "one-line"  -> return OneLineMode
                _           -> readerError $ "unrecognised mode `" ++ opt ++ "'"

-- ** Run

run :: Parser Command
run = fmap Run $ Run.Options
    <$> strOption (mconcat [
        long "entry", short 'e', metavar "NAME",
        value "main", showDefault,
        help "Specify the program entry point"
        ])
    <*> switch (mconcat [
        long "skip-checks",
        help "Skip the correctness checks (from `qux check')"
        ])
    <*> strArgument (mconcat [
        metavar "FILE"
        ])
    <*> many (strArgument $ mconcat [
        metavar "-- ARGS..."
        ])


-- ** Helpers

formatOption :: Mod OptionFields Build.Format -> Parser Build.Format
formatOption = option $ do
    opt <- readerAsk

    case opt of
        "assembly"  -> return Build.Assembly
        "bitcode"   -> return Build.Bitcode
        _           -> readerError $ "unrecognised format `" ++ opt ++ "'"

