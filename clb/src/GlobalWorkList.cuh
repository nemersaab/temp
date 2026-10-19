#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#include "config.h"
#include "stack.cuh"
#include "Counters.cuh"
#include "BWDWorkList.cuh"
#include "helperFunctions.cuh"

#if USE_SHORT_DEGREE
#define INT_OR_SHORT short
#define FUNCTION_NAME(base) base##_short
#define SHARED_MEM_TYPE(base) base##_short
#else
#define INT_OR_SHORT int
#define FUNCTION_NAME(base) base##_int
#define SHARED_MEM_TYPE(base) base##_int
#endif

#if USE_GLOBAL_MEMORY
__global__ void FUNCTION_NAME(GlobalWorkList_global_kernel)(Stacks<INT_OR_SHORT> stacks, unsigned int * minimum, WorkList<INT_OR_SHORT> workList, CSRGraph graph, Counters* counters, int* first_to_dequeue_global, INT_OR_SHORT* global_memory, unsigned long long* NODES_PER_SM, CompArray compArray, unsigned int* compArraySize, unsigned int findBound, unsigned int* numBranches, unsigned int* numBranchesFreq, unsigned int* histogram/*,unsigned int* numDeletedVerticesUnConfined*/) {
#else
__global__ void FUNCTION_NAME(GlobalWorkList_shared_kernel)(Stacks<INT_OR_SHORT> stacks, unsigned int * minimum, WorkList<INT_OR_SHORT> workList, CSRGraph graph, Counters* counters, int* first_to_dequeue_global, unsigned long long* NODES_PER_SM, CompArray compArray, unsigned int* compArraySize, unsigned int findBound, unsigned int* numBranches, unsigned int* numBranchesFreq, INT_OR_SHORT* global_memory, unsigned int* histogram/*,unsigned int* numDeletedVerticesUnConfined*/) {
#endif

    // For Evaluation Purposes
    //__shared__ Counters blockCounters;
 
    Counters blockCounters;
    initializeCounters(&blockCounters);
    
    // For Evaluation Purposes
    #if RUN_KILL_TIMEOUT
    __shared__ long long startingTime;
    __shared__ bool timeOut;
    if (threadIdx.x==0) {
        startingTime = clock64();
        timeOut = false;
    }
    #endif

    #if USE_COUNTERS
        __shared__ unsigned int sm_id;
        if (threadIdx.x==0){
            sm_id=get_smid();
        }
    #endif
    int stackTop = -1;
    unsigned int stackSize = (stacks.minimum + 1);
    volatile INT_OR_SHORT * stackVertexDegrees = &stacks.stacks[(long long)blockIdx.x * (long long)stackSize * (long long)graph.vertexNum];
    volatile unsigned int * stackNumDeletedVertices = &stacks.stacksNumDeletedVertices[blockIdx.x * stackSize];
    volatile int * stackArrayIndex = &stacks.stackArrayIndex[blockIdx.x * stackSize];

    // Define the vertexDegree_s
    unsigned int numDeletedVertices;
    unsigned int numDeletedVertices2;

    INT_OR_SHORT* AuxArray1 ;
    INT_OR_SHORT* AuxArray2 ;
    INT_OR_SHORT* AuxArray3 ;
    INT_OR_SHORT* AuxArray4 ;
    INT_OR_SHORT* AuxArray5 ;
    INT_OR_SHORT* AuxArray6 ;
    INT_OR_SHORT* AuxArray7 ;
    INT_OR_SHORT* AuxArray8 ;
    INT_OR_SHORT* AuxArray9 ;
    INT_OR_SHORT* AuxArray10 ;
    INT_OR_SHORT* AuxArray11 ;
    INT_OR_SHORT* AuxArray12 ;
    INT_OR_SHORT* AuxArray13 ;
    INT_OR_SHORT* AuxArray14 ;
    INT_OR_SHORT* AuxArray15 ;

    
    int arrayIndex = -1;

    #if USE_GLOBAL_MEMORY//casting
    INT_OR_SHORT * vertexDegrees_s = &global_memory[graph.vertexNum*(3*blockIdx.x)];
    INT_OR_SHORT * vertexDegrees_s2 = &global_memory[graph.vertexNum*(3*blockIdx.x + 1)];
    INT_OR_SHORT * vertexDegrees_s3 = &global_memory[graph.vertexNum*(3*blockIdx.x + 2)];
    #else
    extern __shared__ INT_OR_SHORT SHARED_MEM_TYPE(shared_mem)[];
    INT_OR_SHORT * vertexDegrees_s = SHARED_MEM_TYPE(shared_mem);
    INT_OR_SHORT * vertexDegrees_s2 = &SHARED_MEM_TYPE(shared_mem)[graph.vertexNum];
    INT_OR_SHORT * vertexDegrees_s3 = &global_memory[graph.vertexNum*(blockIdx.x)];
    #endif
    
    bool dequeueOrPopNextItr = true; 
    __syncthreads();

    __shared__ bool first_to_dequeue;
    if (threadIdx.x==0) {
        if(atomicCAS(first_to_dequeue_global,0,1) == 0) { 
            first_to_dequeue = true;
        } else {
            first_to_dequeue = false;
        }
    }
    __syncthreads();
    if (first_to_dequeue) {
        for(unsigned int vertex = threadIdx.x; vertex < graph.vertexNum; vertex += blockDim.x) {
            vertexDegrees_s[vertex] = graph.degree[vertex];
        }
        numDeletedVertices = 0;
        dequeueOrPopNextItr = false;
        #if USE_COUNTERS
            if (threadIdx.x==0){
                atomicAdd(&NODES_PER_SM[sm_id],1);
            }
        #endif
    }
    __syncthreads();

    while(true) {
        if(dequeueOrPopNextItr) {
            if(stackTop != -1) { // Local stack is not empty, pop from the local stack
                startTime(POP_FROM_STACK,&blockCounters);
                popStack(graph.vertexNum, vertexDegrees_s, &numDeletedVertices, &arrayIndex, NULL, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, NULL, &stackTop, false);
                endTime(POP_FROM_STACK,&blockCounters);

                #if USE_COUNTERS
                    if (threadIdx.x==0){
                        atomicAdd(&NODES_PER_SM[sm_id],1);
                    }
                #endif
            } else { // Local stack is empty, read from the global workList
                startTime(TERMINATE,&blockCounters);
                startTime(DEQUEUE,&blockCounters);
                if(!dequeue(vertexDegrees_s, workList, graph.vertexNum, &numDeletedVertices, &arrayIndex)) {   
                    endTime(TERMINATE,&blockCounters);
                    break;
                }
                endTime(DEQUEUE,&blockCounters);
                
                // For Debugging Purposes
                /*__shared__ bool conditionn;
                if (threadIdx.x==0) {
                    conditionn = false;
                    for (int i = 0; i<graph.vertexNum; ++i) {
                        if (vertexDegrees_s[i]>0) {
                            unsigned int counter = 0;
                            for(unsigned int edge = graph.srcPtr[i]; edge<graph.srcPtr[i+1]; ++edge) {
                                unsigned int neigh = graph.dst[edge];
                                if(vertexDegrees_s[neigh]>0) {
                                    ++counter;
                                }
                            }
                            if (counter != vertexDegrees_s[i]) {
                                conditionn = true;
                            }
                        }
                    }
                    if (conditionn) {
                        printf("Head = %u, Tail = %u, woklist Baaaaaaaaaaaaaad count = %d, numWait = %d, numEnq = %d\n",
                           (unsigned int)(*workList.head_tail & 0xFFFFFFFF),
                           (unsigned int)((*workList.head_tail >> 32) & 0xFFFFFFFF),
                           *workList.count,
                           workList.counter->numWaiting,
                           workList.counter->numEnqueued
                        );
                    } else {
                        printf("Head = %u, Tail = %u, woklist count = %d, numWait = %d, numEnq = %d\n",
                           (unsigned int)(*workList.head_tail & 0xFFFFFFFF),
                           (unsigned int)((*workList.head_tail >> 32) & 0xFFFFFFFF),
                           *workList.count,
                           workList.counter->numWaiting,
                           workList.counter->numEnqueued
                        );
                    }
                }
                __syncthreads();*/

                #if USE_COUNTERS
                    if (threadIdx.x==0){
                        atomicAdd(&NODES_PER_SM[sm_id],1);
                    }
                #endif
            }
        }
        __syncthreads();
        
        __shared__ unsigned int left;
        __shared__ unsigned int right;
        if(threadIdx.x == 0){
            left = graph.vertexNum-1;
            right = 0;
        }
        __syncthreads();
        
        if (findBound) {
            startTime(FIND_BOUND,&blockCounters);
            findBoundaries(vertexDegrees_s, &left, &right, graph.vertexNum);
            endTime(FIND_BOUND,&blockCounters);
        }

        __shared__ int minimum_s;
        if(threadIdx.x == 0) {
            if (arrayIndex>-1) {
                minimum_s = atomicOr((int*)&compArray.entries[arrayIndex].minimum,0);
            } else {
                minimum_s = atomicOr(minimum,0);
            }
            
            if (right == 0) {
                left = 0;
                right = graph.vertexNum-1;
            }
            
            // For Evaluation Purposes
            #if RUN_KILL_TIMEOUT
            if (clock64() - startingTime > 25000000000000) {
                timeOut = true;
            }
            #endif
        }
        __syncthreads();

        // For Evaluation Purposes
        #if RUN_KILL_TIMEOUT
        if (timeOut) {
            stackTop = -1;
            dequeueOrPopNextItr = true;
            continue;
        }
        #endif
        int performMatchingRules = 0;
        if(stackTop + 15 < stackSize){
            performMatchingRules =1;
            AuxArray1 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-1)*graph.vertexNum];
            AuxArray2 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-2)*graph.vertexNum];
            AuxArray3 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-3)*graph.vertexNum];
            AuxArray4 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-4)*graph.vertexNum];
            AuxArray5 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-5)*graph.vertexNum];
            AuxArray6 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-6)*graph.vertexNum];
            AuxArray7 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-7)*graph.vertexNum];
            AuxArray8 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-8)*graph.vertexNum];
            AuxArray9 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-9)*graph.vertexNum];
            AuxArray10 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-10)*graph.vertexNum];
            AuxArray11 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-11)*graph.vertexNum];
            AuxArray12 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-12)*graph.vertexNum];
            AuxArray13 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-13)*graph.vertexNum];
            AuxArray14 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-14)*graph.vertexNum];
            AuxArray15 = (INT_OR_SHORT*)&stackVertexDegrees[(stackSize-15)*graph.vertexNum];
        } 
        int performReduction = 1;
        if(minimum_s == -1){ //RemoveMaxApproximateMVC update
            // performReduction = 0;
            unsigned int minApp = RemoveMaxApproximateMVC( graph, vertexDegrees_s, vertexDegrees_s2, vertexDegrees_s3, minimum_s, left, right);
            if(threadIdx.x == 0){
                int parentArrayIdx = compArray.entries[arrayIndex].index;
                int minParent = atomicOr((int*)&compArray.entries[parentArrayIdx].minimum,0);
                int parentAncestor = atomicOr((int*)&compArray.entries[parentArrayIdx].index,0);
                int parentBest;
                if(parentAncestor >-1) {
                    parentBest = atomicOr((int*)&compArray.entries[parentAncestor].minimum,0);
                }
                else{
                    parentBest = atomicOr(minimum,0);
                }
                if(parentBest<=minParent) {
                    compArray.entries[arrayIndex].minimum = 0;
                    minimum_s = 0;
                }
                else{
                    compArray.entries[arrayIndex].minimum = (minApp< parentBest-minParent)?minApp:parentBest-minParent;
                    minimum_s = compArray.entries[arrayIndex].minimum;
                }    
            }
        }
        __syncthreads();
         if(performReduction == 1){
            unsigned int iterationCounter = 0, numDeletedVerticesLeaf, numDeletedVerticesTriangle, numDeletedVerticesHighDegree, numDeletedVerticesInducedClique,numDeletedVerticesDominance,numDeleltedVerteicesUnConfined, numDeletedVerticesLP;
             while(true){
                    startTime(LEAF_REDUCTION,&blockCounters);
                    numDeletedVerticesLeaf = leafReductionRule(graph.vertexNum, vertexDegrees_s, graph, vertexDegrees_s2, left, right);
                    endTime(LEAF_REDUCTION,&blockCounters);
                    numDeletedVertices += numDeletedVerticesLeaf;
                    
                    startTime(TRIANGLE_REDUCTION,&blockCounters);
                    numDeletedVerticesTriangle = triangleReductionRule(graph.vertexNum, vertexDegrees_s, graph, vertexDegrees_s2, left, right);
                    endTime(TRIANGLE_REDUCTION,&blockCounters);
                    numDeletedVertices += numDeletedVerticesTriangle;
                    if(numDeletedVerticesTriangle>0)  
                        continue;

                    startTime(HIGH_DEGREE_REDUCTION,&blockCounters);
                    numDeletedVerticesHighDegree = highDegreeReductionRule(graph.vertexNum, vertexDegrees_s, graph, vertexDegrees_s2,numDeletedVertices,minimum_s, left, right);
                    endTime(HIGH_DEGREE_REDUCTION,&blockCounters);
                    numDeletedVertices += numDeletedVerticesHighDegree;
                    if(numDeletedVerticesHighDegree>0)  
                        continue;
                    
                    /*startTime(INDUCED_CLIQUE_REDUCTION,&blockCounters);
                    numDeletedVerticesInducedClique = inducedCliqueReductionRule(graph.vertexNum, vertexDegrees_s, graph, vertexDegrees_s2, left, right);
                    endTime(INDUCED_CLIQUE_REDUCTION,&blockCounters);
                    numDeletedVertices += numDeletedVerticesInducedClique;
                    if(numDeletedVerticesInducedClique>0)  
                        continue;
                    */
                    startTime(DOMINANCE_REDUCTION,&blockCounters);
                    numDeletedVerticesDominance = DominanceRule(graph.vertexNum, vertexDegrees_s, graph, vertexDegrees_s2, left, right);
                    endTime(DOMINANCE_REDUCTION,&blockCounters);
                    numDeletedVertices += numDeletedVerticesDominance;
                    if(numDeletedVerticesDominance>0)  
                        continue;
                    if ((sizeof(vertexDegrees_s[0])==4 || (sizeof(vertexDegrees_s[0])==2 && (graph.vertexNum-right)<=32768))){
                        startTime(UNCONFINED_REDUCTION,&blockCounters);
                        numDeleltedVerteicesUnConfined = unconfinedVertexRule(graph.vertexNum, vertexDegrees_s, graph, vertexDegrees_s2, left, right);
                        endTime(UNCONFINED_REDUCTION,&blockCounters);
                        numDeletedVertices += numDeleltedVerteicesUnConfined;
                        if(numDeleltedVerteicesUnConfined>0)  
                            continue;
                    } 
                    /*if(performMatchingRules){
                        startTime(LP_REDUCTION,&blockCounters);
                        numDeletedVerticesLP = lpReductionRule(graph, vertexDegrees_s, AuxArray1, AuxArray2, AuxArray3, AuxArray4, AuxArray5, AuxArray6, AuxArray7, AuxArray8, AuxArray9, AuxArray10, AuxArray11, AuxArray12, AuxArray13, AuxArray14, AuxArray15,left, right);
                        endTime(LP_REDUCTION,&blockCounters);
                        numDeletedVertices += numDeletedVerticesLP;
                        if(numDeletedVerticesLP>0)
                            continue;  
                    }*/
                    break;

                }
        
        }
         else{
             unsigned int numDeletedVerticesHighDegree;
             startTime(HIGH_DEGREE_REDUCTION,&blockCounters);
             numDeletedVerticesHighDegree = highDegreeReductionRule(graph.vertexNum, vertexDegrees_s, graph, vertexDegrees_s2,numDeletedVertices,minimum_s, left, right);
             endTime(HIGH_DEGREE_REDUCTION,&blockCounters);
             numDeletedVertices += numDeletedVerticesHighDegree;
         }
        startTime(NUM_EDGES,&blockCounters);
        unsigned int numOfEdges = findNumOfEdges(graph.vertexNum, vertexDegrees_s, vertexDegrees_s2, left, right);
        endTime(NUM_EDGES,&blockCounters);

        bool numEdgesCondition = false;
        if(numOfEdges>=square((int)minimum_s-(int)numDeletedVertices-1)+1) {
            numEdgesCondition = true;
        }
        __syncthreads();

        if(threadIdx.x == 0) {
            if (arrayIndex>-1) {
                minimum_s = atomicOr((int*)&compArray.entries[arrayIndex].minimum,0);
            } else {
                minimum_s = atomicOr(minimum,0);
            }
            // For Debugging Purposes
            //printf("I am Alive blockIdx.x = %d and stackTop = %d and minim = %u\n", blockIdx.x, stackTop, minimum_s);
        }
        __syncthreads();
        startTime(CLIQUE_LOWERBOUND,&blockCounters);
        int clb = cliqueLowerBound(graph, vertexDegrees_s, vertexDegrees_s2, vertexDegrees_s3, left, right);
        endTime(CLIQUE_LOWERBOUND,&blockCounters);
        int cylb = 0;
        int lplb = 0;
        /*if(performMatchingRules) {
            startTime(CYCLE_LOWERBOUND,&blockCounters);
            cylb = cycleLowerBound(graph, vertexDegrees_s, AuxArray1, AuxArray2, AuxArray3, AuxArray4, AuxArray5, AuxArray6, AuxArray7, AuxArray8, AuxArray9, AuxArray10, AuxArray11, AuxArray12, AuxArray13, AuxArray14, AuxArray15,left, right);
            endTime(CYCLE_LOWERBOUND,&blockCounters);
            startTime(LP_LOWERBOUND,&blockCounters);
            lplb = lpLowerBound(graph, vertexDegrees_s, vertexDegrees_s2, left, right);
            endTime(LP_LOWERBOUND,&blockCounters);
        }
            int lb = (clb > cylb)? clb:cylb;
            if (lplb>lb) {
                lb = lplb;
            }*/
	int lb = clb;
        if(numDeletedVertices>=minimum_s || numEdgesCondition ||lb + numDeletedVertices >= minimum_s) { // Reached the bottom of the tree, no minimum vertex cover found
            if(threadIdx.x==0 && arrayIndex>-1) {
                int counter = atomicSub((int*)&compArray.entries[arrayIndex].counter, 1);
                if (counter==1) {
                    int parentIndex = compArray.entries[arrayIndex].index;
                    atomicAdd((int*)&compArray.entries[parentIndex].minimum, compArray.entries[arrayIndex].minimum);
                    int parentCounter = atomicSub((int*)&compArray.entries[parentIndex].counter, 1);
                    if (parentCounter==1) {
                        arrayIndex = compArray.entries[parentIndex].index;
                        numDeletedVertices = atomicOr((int*)&compArray.entries[parentIndex].minimum,0);
                        while (true) {
                            if (arrayIndex>-1) {
                                atomicMin((int*)&compArray.entries[arrayIndex].minimum, numDeletedVertices);
                                int counter = atomicSub((int*)&compArray.entries[arrayIndex].counter, 1);
                                if (counter-1>0) {
                                    break;
                                }
                                int parentIndex = compArray.entries[arrayIndex].index;
                                atomicAdd((int*)&compArray.entries[parentIndex].minimum, compArray.entries[arrayIndex].minimum);
                                int parentCounter = atomicSub((int*)&compArray.entries[parentIndex].counter, 1);
                                if (parentCounter-1>0) {
                                    break;
                                }
                                arrayIndex = compArray.entries[parentIndex].index;
                                numDeletedVertices = atomicOr((int*)&compArray.entries[parentIndex].minimum,0);

                            } else {
                                atomicMin(minimum, numDeletedVertices);
                                break;
                            }
                        }
                    }
                }
            }
            dequeueOrPopNextItr = true;
            __syncthreads();

        } else {

            int isComponents = 1;
            startTime(COMP_SEARCH,&blockCounters);
            //isComponents = bfsConnectedComp_Hybrid(graph.vertexNum, vertexDegrees_s, graph, vertexDegrees_s2, arrayIndex, minimum_s, numDeletedVertices, compArray, workList, &blockCounters, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, &stackTop, stackSize, *compArraySize, left, right);
            //isComponents = bfs_Hybrid(graph.vertexNum, vertexDegrees_s, graph, vertexDegrees_s2, arrayIndex, minimum_s, numDeletedVertices, compArray, workList, &blockCounters, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, &stackTop, stackSize, *compArraySize, left, right);
            isComponents = bfsCC_Hybrid(graph.vertexNum, vertexDegrees_s, graph, vertexDegrees_s2, arrayIndex, minimum_s, &numDeletedVertices, compArray, workList, &blockCounters, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, &stackTop, stackSize, *compArraySize, left, right, minimum, histogram);
            endTime(COMP_SEARCH,&blockCounters);
             __syncthreads();

            unsigned int maxVertex;
            INT_OR_SHORT maxDegree;
            if (isComponents>1) {
                #if COUNT_BRANCHING_ON_COMPONENTS
                if (threadIdx.x==0) {
                   atomicAdd(numBranches, 1);
                   atomicAdd(&numBranchesFreq[isComponents], 1);
                }
                __syncthreads();
                #endif
                dequeueOrPopNextItr = true;
                __syncthreads();

            } else if (isComponents==0) { // Reached the bottom of the tree, minimum vertex cover possibly found
                if(threadIdx.x==0) {
                    while (true) {
                        if (arrayIndex>-1) {
                            atomicMin((int*)&compArray.entries[arrayIndex].minimum, numDeletedVertices);
                            int counter = atomicSub((int*)&compArray.entries[arrayIndex].counter, 1);
                            if (counter-1>0) {
                                break;
                            }
                            int parentIndex = compArray.entries[arrayIndex].index;
                            atomicAdd((int*)&compArray.entries[parentIndex].minimum, compArray.entries[arrayIndex].minimum);
                            int parentCounter = atomicSub((int*)&compArray.entries[parentIndex].counter, 1);
                            if (parentCounter-1>0) {
                                break;
                            }
                            arrayIndex = compArray.entries[parentIndex].index;
                            numDeletedVertices = atomicOr((int*)&compArray.entries[parentIndex].minimum,0);
                        } else {
                            atomicMin(minimum, numDeletedVertices);
                            break;
                        }
                    }
                }
                dequeueOrPopNextItr = true;
                __syncthreads();

            } else {
                // Vertex cover not found, need to branch
                // __shared__ unsigned int compSize;
                // if(threadIdx.x == 0) {
                //     compSize = 0;
                    
                // }
                // __syncthreads();
                
                // for(unsigned int vertex = left+threadIdx.x; vertex <= right; vertex+=blockDim.x) {
                //         if(vertexDegrees_s[vertex]>0) {
                //             atomicAdd(&compSize, 1);
                //         }
                //     }
                
                // __syncthreads();

                if(threadIdx.x == 0) {
                    // if(compSize > graph.vertexNum) {
                    //     printf("Error: compSize = %u, graph.vertexNum = %u\n", compSize, graph.vertexNum);
                    // }
                    // if (compSize > 0 )
                    //     atomicAdd(&histogram[compSize-1], 1);

                    if (arrayIndex>-1) {
                        atomicAdd((int*)&compArray.entries[arrayIndex].counter, 1);
                    }
                }
                __syncthreads();
                
                startTime(MAX_DEGREE,&blockCounters);
                findMaxDegree(graph.vertexNum, &maxVertex, &maxDegree, vertexDegrees_s, vertexDegrees_s2, left, right);
                endTime(MAX_DEGREE,&blockCounters);

                startTime(PREPARE_RIGHT_CHILD,&blockCounters);
                deleteNeighborsOfMaxDegreeVertex(graph,vertexDegrees_s, &numDeletedVertices, vertexDegrees_s2, &numDeletedVertices2, maxDegree, maxVertex);
                endTime(PREPARE_RIGHT_CHILD,&blockCounters);

                bool enqueueSuccess;
                if(checkThreshold(workList)) {
                    startTime(ENQUEUE,&blockCounters);
                    enqueueSuccess = enqueue(vertexDegrees_s2, workList, graph.vertexNum, &numDeletedVertices2, arrayIndex);
                } else  {
                    enqueueSuccess = false;
                }
                __syncthreads();

                if(!enqueueSuccess) {
                    startTime(PUSH_TO_STACK,&blockCounters);
                    pushStack(graph.vertexNum, vertexDegrees_s2, &numDeletedVertices2, arrayIndex, NULL, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, NULL, &stackTop, false);
                    endTime(PUSH_TO_STACK,&blockCounters);
                    maxDepth(stackTop, &blockCounters);
                } else {
                    endTime(ENQUEUE,&blockCounters);
                }
                __syncthreads();

                startTime(PREPARE_LEFT_CHILD,&blockCounters);
                // Prepare the child that removes the neighbors of the max vertex to be processed on the next iteration
                deleteMaxDegreeVertexMirror(graph, vertexDegrees_s,vertexDegrees_s2,vertexDegrees_s3, &numDeletedVertices, maxVertex);
                endTime(PREPARE_LEFT_CHILD,&blockCounters);

                #if USE_COUNTERS
                    if (threadIdx.x==0) {
                        atomicAdd(&NODES_PER_SM[sm_id],1);
                    }
                #endif

                dequeueOrPopNextItr = false;
                __syncthreads();
            }
        }
        __syncthreads();
    }

    // For Debugging Purposes
    /*if (blockIdx.x==0) {
        if (threadIdx.x==0) {
            int globIndex = (*compArray.globalArrayIndex<*compArraySize)?*compArray.globalArrayIndex:*compArraySize;
            for(unsigned int vertex = 0; vertex<globIndex; vertex++) {
                printf("index = %d\n",vertex);
                printf("counter = %d\n",compArray.entries[vertex].counter);
                printf("minimum = %d\n",compArray.entries[vertex].minimum);
                printf("index = %d\n\n",compArray.entries[vertex].index);
            }
        }
    }*/

    #if USE_COUNTERS
    if(threadIdx.x == 0) {
        counters[blockIdx.x] = blockCounters;
    }
    #endif
}

#undef INT_OR_SHORT
#undef FUNCTION_NAME(base)
#undef SHARED_MEM_TYPE(base)
