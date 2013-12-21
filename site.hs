--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Control.Applicative ((<$>))
import           Data.Monoid (mappend)
import           Hakyll


--------------------------------------------------------------------------------
main :: IO ()
main = hakyllWith config $ do
    match ("images/*" .||. "favicon.ico" .||. "js/*" .||. "resources/*") $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match "projects/*/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    match "projects/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "projects/*/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    create ["projects.html"] $ do
        route idRoute
        compile $ do
            projects <- recentFirst =<< loadAll "projects/*"
            let projectCtx =
                    listField "projects" defaultContext (return projects) `mappend`
                    constField "title" "Projects"                  `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/project.html" projectCtx
                >>= loadAndApplyTemplate "templates/default.html" projectCtx
                >>= relativizeUrls

    create ["atom.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx `mappend` bodyField "description"
            posts <- (take 10) <$> (recentFirst =<< loadAllSnapshots "projects/*/*" "content")
            renderAtom atomFeedConfig feedCtx posts


    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- (take 5) <$> (recentFirst =<< loadAll "projects/*/*")
            projects <- recentFirst =<< loadAll "projects/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    listField "projects" defaultContext (return projects) `mappend`
                    constField "title" "Home"                `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext

config :: Configuration
config = defaultConfiguration
         { deployCommand = "rsync -avz -e ssh ./_site/ Neophilus:www/cqplabs" }

atomFeedConfig :: FeedConfiguration
atomFeedConfig = FeedConfiguration
    { feedTitle       = "CQPLabs"
    , feedDescription = "The hare-brained scheme division of CQP"
    , feedAuthorName  = "CQPLabs"
    , feedAuthorEmail = "cqplabs@rmit.edu.au"
    , feedRoot        = "http://cqplabs.neophilus.net"
    }

