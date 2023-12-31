\name{reduceByRange}

\alias{reduceByRange}
\alias{reduceByRange,GRanges,ANY-method}
\alias{reduceByRange,GRangesList,ANY-method}
\alias{reduceByRange,GenomicFiles,missing-method}

\alias{reduceRanges}

\title{Parallel computations by ranges}

\description{
  Computations are distributed in parallel by range. Data subsets are
  extracted and manipulated (MAP) and optionally combined (REDUCE)
  across all files.
}

\usage{
\S4method{reduceByRange}{GRanges,ANY}(ranges, files, MAP,
    REDUCE, ..., summarize=FALSE, iterate=TRUE, init)
\S4method{reduceByRange}{GRangesList,ANY}(ranges, files, MAP,
    REDUCE, ..., summarize=FALSE, iterate=TRUE, init)
\S4method{reduceByRange}{GenomicFiles,missing}(ranges, files, MAP,
    REDUCE, ..., summarize=FALSE, iterate=TRUE, init)

reduceRanges(ranges, files, MAP, REDUCE, ..., init)
}

\arguments{
  \item{ranges}{
    A \code{GRanges}, \code{GrangesList} or \code{GenomicFiles}
    object.

    A \code{GRangesList} implies a grouping of the ranges; \code{MAP}
    is applied to each element of the \code{GRangesList} vs each range
    when \code{ranges} is a \code{GRanges}.

    When \code{ranges} is a \code{GenomicFiles} the \code{files}
    argument is missing; both ranges and files are extracted
    from the object.
  }
  \item{files}{
    A \code{character} vector or \code{List} of filenames. A \code{List}
    implies a grouping of the files; \code{MAP} is applied to each
    element of the \code{List} vs each file individually.
  }
  \item{MAP}{
    A function executed on each worker. The signature must contain a
    minimum of two arguments representing the ranges and files. There is no
    restriction on argument names and additional arguments can be provided.

    \itemize{
      \item \code{MAP = function(range, file, ...)}
    }
  }

  \item{REDUCE}{
    An optional function that combines output from the \code{MAP} step
    applied across all files. The signature must contain at least one
    argument representing the list output from \code{MAP}. There is no
    restriction on argument names and additional arguments can be
    provided.

    \itemize{
      \item \code{REDUCE = function(mapped, ...)}
    }

    Reduction combines data from a single worker and is always
    performed as part of the distributed step. When \code{iterate=TRUE}
    \code{REDUCE} is applied after each \code{MAP} step;
    depending on the nature of \code{REDUCE}, iterative reduction
    can substantially decrease the data stored in memory. When
    \code{iterate=FALSE} reduction is applied to the list of \code{MAP}
    outputs for a single range, applied to all files.

    When \code{REDUCE} is missing, output is a list from \code{MAP}.
  }
  \item{iterate}{
    A logical that, when \code{TRUE}, indicates that the \code{REDUCE}
    function should be applied iteratively to the output of
    \code{MAP}. When \code{REDUCE} is missing \code{iterate} is set to
    FALSE. This argument applies to \code{reduceByRange} only.

    Collapsing results iteratively is useful when the number of
    records to be processed is large (maybe complete files) but
    the end result is a much reduced representation of all records.
    Iteratively applying \code{REDUCE} reduces the amount of
    data on each worker at any one time and can substantially
    reduce the memory footprint.
  }
  \item{summarize}{
    A logical indicating if results should be returned as a
    \code{SummarizedExperiment} object instead of a list;
    data are returned in the \code{assays} slot named `data`.
    This argument applies to \code{reduceByRange} only.

    When \code{REDUCE} is provided \code{summarize} is ignored
    (i.e., set to FALSE). A \code{SummarizedExperiment} requires the number
    of rows in \code{colData} and the columns in \code{assays} to match.
    Because \code{REDUCE} collapses the data across files, the dimension of
    the result no longer matches that of the original ranges.
  }
  \item{init}{
    An optional initial value for \code{REDUCE} when
    \code{iterate=TRUE}. \code{init} must be an object of the same
    type as the elements returned from \code{MAP}. \code{REDUCE}
    logically adds \code{init} to the start (when proceeding left
    to right) or end of results obtained with \code{MAP}.
  }
  \item{\dots}{
    Arguments passed to other methods. Currently not used.
  }
}

\details{
  \code{reduceByRange} extracts, manipulates and combines ranges across
  different files. Each element of \code{ranges} is sent to a worker;
  this is a single range when \code{ranges} is a GRanges and may be
  multiple ranges when \code{ranges} is a GRangesList. The worker then
  iterates across all files, applying \code{MAP(range, file, ...)} to
  each.  When \code{iterate=FALSE}, \code{REDUCE} is applied to the list
  of results from \code{MAP} applied to all files. When \code{iterate =
  TRUE}, the argument to \code{REDUCE} is always a list of length
  2. \code{REDUCE} is first invoked after the second file has been
  processed. The first element of the list to \code{REDUCE} is the
  result of calling \code{MAP} on the first file; the second element is
  the result of calling \code{MAP} on the second file. For the
  \code{n}th file, the first element is the result of the call to
  \code{REDUCE} for the \code{n-1}th file, and the second element is the
  result of calling \code{MAP} on the \code{n}th file.

  \code{reduceRanges} is essentially equivalent to \code{reduceByRange},
  but with \code{iterate = FALSE}.

  Both \code{MAP} and \code{REDUCE} are applied in the distributed step
  (``on the worker``). \code{REDUCE} provides a way to summarize results
  for a single range across all files; \code{REDUCE} does \emph{not}
  provide a mechanism to summarize results across ranges.
}

\value{
  \itemize{
    \item{reduceByRange:}{
      When \code{summarize=FALSE} the return value is a \code{list} or
      the value from the final invocation of \code{REDUCE}. When
      \code{summarize=TRUE} output is a \code{SummarizedExperiment}.
      When \code{ranges} is a \code{GenomicFiles} object data from
      \code{rowRanges}, \code{colData} and \code{metadata} are transferred
      to the \code{SummarizedExperiment}.
    }
    \item{reduceRanges:}{
      A \code{list} or the value returned by the final invocation of
      \code{REDUCE}.
    }
  }
}

\seealso{
  \itemize{
    \item \link{reduceFiles}
    \item \link{reduceByFile}
    \item \link{GenomicFiles-class}
  }
}

\author{
  Martin Morgan and Valerie Obenchain
}

\examples{

if (all(requireNamespace("RNAseqData.HNRNPC.bam.chr14", quietly=TRUE) &&
        require(GenomicAlignments))) {
  ## -----------------------------------------------------------------------
  ## Compute coverage across BAM files.
  ## -----------------------------------------------------------------------
  fls <-                                ## 8 bam files
      RNAseqData.HNRNPC.bam.chr14::RNAseqData.HNRNPC.bam.chr14_BAMFILES

  ## Regions of interest.
  gr <- GRanges("chr14", IRanges(c(62262735, 63121531, 63980327),
                width=214700))

  ## The MAP computes the coverage ...
  MAP <- function(range, file, ...) {
      requireNamespace("GenomicFiles", quietly=TRUE)
      ## for coverage(), Rsamtools::ScanBamParam()
      param = Rsamtools::ScanBamParam(which=range)
      GenomicFiles::coverage(file, param=param)[range]
  }
  ## and REDUCE adds the last and current results.
  REDUCE <- function(mapped, ...)
      Reduce("+", mapped)

  ## -----------------------------------------------------------------------
  ## reduceByRange:

  ## With no REDUCE, coverage is computed for each range / file combination.
  cov1 <- reduceByRange(gr, fls, MAP)
  cov1[[1]]

  ## Each call to coverage() produces an RleList which accumulate on the
  ## workers. We can use a reducer to combine these lists either iteratively
  ## or non-iteratively. When iterate = TRUE the current result
  ## is collapsed with the last resulting in a maximum of 2 RleLists on
  ## a worker at any given time.
  cov2 <- reduceByRange(gr, fls, MAP, REDUCE, iterate=TRUE)
  cov2[[1]]

  ## If memory use is not a concern (or if MAP output is not large) the
  ## REDUCE function can be applied non-iteratively.
  cov3 <- reduceByRange(gr, fls, MAP, REDUCE, iterate=FALSE)

  ## Results match those obtained with the iterative REDUCE.
  cov3[[1]]

  ## When 'ranges' is a GRangesList, the list elements are sent to the
  ## workers instead of a single range as in the case of a GRanges.
  grl <- GRangesList(gr[1], gr[2:3])
  grl

  cov4 <- reduceByRange(grl, fls, MAP)
  length(cov4)          ## length of GRangesList
  elementNROWS(cov4)  ## number of files

  ## -----------------------------------------------------------------------
  ## reduceRanges:

  ## This function passes the character vector of all file names to MAP.
  ## MAP must handle each file separately or invoke a method that operates
  ## on a list of files.

  ## TODO: example
}
}

\keyword{methods}
