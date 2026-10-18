#if (!defined(HELPFUNCSHORT_H) && USE_SHORT_DEGREE) || (!defined(HELPFUNCINT_H) && !USE_SHORT_DEGREE)

#include "config.h"
#include "BWDWorkList.cuh"
#include "stack.cuh"
#include <set>
#if USE_SHORT_DEGREE
#define HELPFUNCSHORT_H
#define INT_OR_SHORT short
#define ATOMIC_TYPE(base) base##Short
// #define WARP_SIZE 32
// #define BLOCK_DIM 1024
__device__ short atomicSubShort(short* address, short val) {
    // Convert the short* address to a char* for byte-level operations
    char* addr_as_char = (char*)address;

    // Compute the base address aligned to 4 bytes (32 bits)
    char* base_addr_char = addr_as_char - ((size_t)addr_as_char % 4);
    int* base_addr = (int*)base_addr_char;

    // Calculate the offset within the 32-bit word (0 or 2)
    size_t offset = (size_t)(addr_as_char - base_addr_char);

    int old = *base_addr;
    int assumed;
    int newval;
    short old_short;

    do {
        assumed = old;

        // Extract the lower and upper 16 bits
        short low = (short)(old & 0xFFFF);
        short high = (short)((old >> 16) & 0xFFFF);

        if (offset == 0) {
            // We are working with the lower 16 bits
            old_short = low;
            low = old_short - val;
        } else {
            // We are working with the upper 16 bits
            old_short = high;
            high = old_short - val;
        }

        // Reconstruct the 32-bit integer
        newval = ((int)(unsigned short)high << 16) | (unsigned short)(low);

        // Attempt to atomically update the 32-bit word
        old = atomicCAS(base_addr, assumed, newval);
    } while (assumed != old);

    return old_short;
}
__device__ short atomicCASShort(short* address, short compare, short val) {
    // Convert the short* address to a char* for byte-level operations
    char* addr_as_char = (char*)address;

    // Compute the base address aligned to 4 bytes (32 bits)
    char* base_addr_char = addr_as_char - ((size_t)addr_as_char % 4);
    int* base_addr = (int*)base_addr_char;

    // Calculate the offset within the 32-bit word (0 or 2)
    size_t offset = (size_t)(addr_as_char - base_addr_char);

    int old = *base_addr;
    int assumed;
    short old_short;

    do {
        assumed = old;

        // Extract the lower and upper 16 bits
        short low  = (short)(assumed & 0xFFFF);
        short high = (short)((assumed >> 16) & 0xFFFF);

        old_short = (offset == 0) ? low : high;

        // If the current value doesn't match `compare`, a real atomicCAS
        // would just return the observed value without writing — do the same.
        if (old_short != compare) {
            return old_short;
        }

        // Splice `val` into the half we're targeting, leave the other half untouched
        int newval;
        if (offset == 0) {
            newval = ((int)(unsigned short)high << 16) | (unsigned short)val;
        } else {
            newval = ((int)(unsigned short)val << 16) | (unsigned short)low;
        }

        old = atomicCAS(base_addr, assumed, newval);
    } while (assumed != old);

    return old_short; // will equal `compare`, since we only reach here on success
}
__device__ short atomicExchShort(short* address, short val) {
    // Convert the short* address to a char* for byte-level operations
    char* addr_as_char = (char*)address;

    // Compute the base address aligned to 4 bytes (32 bits)
    char* base_addr_char = addr_as_char - ((size_t)addr_as_char % 4);
    int* base_addr = (int*)base_addr_char;

    // Calculate the offset within the 32-bit word (0 or 2)
    size_t offset = (size_t)(addr_as_char - base_addr_char);

    int old = *base_addr;
    int assumed;
    int newval;
    short old_short;

    do {
        assumed = old;

        // Extract the lower and upper 16 bits
        short low = (short)(assumed & 0xFFFF);
        short high = (short)((assumed >> 16) & 0xFFFF);

        if (offset == 0) {
            // We are working with the lower 16 bits
            old_short = low;
            low = val;
        } else {
            // We are working with the upper 16 bits
            old_short = high;
            high = val;
        }

        // Reconstruct the 32-bit integer
        newval = ((int)(unsigned short)high << 16) | (unsigned short)(low);

        // Attempt to atomically update the 32-bit word
        old = atomicCAS(base_addr, assumed, newval);
    } while (assumed != old);

    return old_short;
}
__device__ short atomicAddShort(short* address, short val) {
    // Convert the short* address to a char* for byte-level operations
    char* addr_as_char = (char*)address;

    // Compute the base address aligned to 4 bytes (32 bits)
    char* base_addr_char = addr_as_char - ((size_t)addr_as_char % 4);
    int* base_addr = (int*)base_addr_char;

    // Calculate the offset within the 32-bit word (0 or 2)
    size_t offset = (size_t)(addr_as_char - base_addr_char);

    int old = *base_addr;
    int assumed;
    int newval;
    short old_short;

    do {
        assumed = old;

        // Extract the lower and upper 16 bits
        short low = (short)(old & 0xFFFF);
        short high = (short)((old >> 16) & 0xFFFF);

        if (offset == 0) {
            // We are working with the lower 16 bits
            old_short = low;
            low = old_short + val;
        } else {
            // We are working with the upper 16 bits
            old_short = high;
            high = old_short + val;
        }

        // Reconstruct the 32-bit integer
        newval = ((int)(unsigned short)high << 16) | (unsigned short)(low);

        // Attempt to atomically update the 32-bit word
        old = atomicCAS(base_addr, assumed, newval);
    } while (assumed != old);

    return old_short;
}

__device__ void saveIntInShortArray(volatile short* arr, int value) {
    arr[0] = value & 0xFFFF;          // Lower 16 bits
    arr[1] = (value >> 16) & 0xFFFF;  // Upper 16 bits
}

__device__ void saveIntInShortArray(short* arr, int value) {
    arr[0] = value & 0xFFFF;          // Lower 16 bits
    arr[1] = (value >> 16) & 0xFFFF;  // Upper 16 bits
}

__device__ int readIntFromShortArray(volatile short* arr) {
    int value = (static_cast<int>(arr[1]) << 16) | (static_cast<unsigned short>(arr[0]));
    return value;
}

__device__ int readIntFromShortArray(short* arr) {
    int value = (static_cast<int>(arr[1]) << 16) | (static_cast<unsigned short>(arr[0]));
    return value;
}

__device__ void AddIntInShortArray(volatile short* arr, int value) {
    int currentValue = readIntFromShortArray(arr);
    int newValue = currentValue + value;
    saveIntInShortArray(arr, newValue);
}

__device__ void AddIntInShortArray(short* arr, int value) {
    int currentValue = readIntFromShortArray(arr);
    int newValue = currentValue + value;
    saveIntInShortArray(arr, newValue);
}


#else
#define HELPFUNCINT_H
#define INT_OR_SHORT int
#define ATOMIC_TYPE(base) base

__device__ long long int square(int num) {
    return num*num;
}

__device__ bool binarySearch(unsigned int * arr,  int l, int r, unsigned int x) {

   while (l <= r) {
        int m = l + (r - l) / 2;
        if (arr[m] == x)
            return  true;
  
        if (arr[m] < x)
            l = m + 1;
  
        else
            r = m - 1;
    }
    return false;
}

#endif

__device__ void findBoundaries(INT_OR_SHORT* vertexDegrees_s, unsigned int* left, unsigned int* right, int vertexNum){
    for(unsigned int vertex = threadIdx.x; vertex < vertexNum; vertex += blockDim.x){
        if(vertexDegrees_s[vertex] > 0){
            atomicMin(left,vertex);
            break;
        }
    }
    for(int vertex = vertexNum-(int)(threadIdx.x)-1; vertex > -1; vertex -= (int)blockDim.x){
        if(vertexDegrees_s[vertex] > 0){
            atomicMax(right,vertex);
            break;
        }
    }
    __syncthreads();
}

__device__ void deleteNeighborsOfMaxDegreeVertex(CSRGraph graph, INT_OR_SHORT* vertexDegrees_s, unsigned int* numDeletedVertices, INT_OR_SHORT* vertexDegrees_s2, unsigned int* numDeletedVertices2, INT_OR_SHORT maxDegree, unsigned int maxVertex) {

    *numDeletedVertices2 = *numDeletedVertices;
    for(unsigned int vertex = threadIdx.x; vertex<graph.vertexNum; vertex+=blockDim.x){
        vertexDegrees_s2[vertex] = vertexDegrees_s[vertex];
    }
    __syncthreads();

    for(unsigned int edge = graph.srcPtr[maxVertex] + threadIdx.x; edge < graph.srcPtr[maxVertex + 1]; edge+=blockDim.x) { // Delete Neighbors of maxVertex
        unsigned int neighbor = graph.dst[edge];
        if (vertexDegrees_s2[neighbor] > 0){
            for(unsigned int neighborEdge = graph.srcPtr[neighbor]; neighborEdge < graph.srcPtr[neighbor + 1]; ++neighborEdge) {
                unsigned int neighborOfNeighbor = graph.dst[neighborEdge];
                if(vertexDegrees_s2[neighborOfNeighbor] > 0) {
                    ATOMIC_TYPE(atomicSub)(&vertexDegrees_s2[neighborOfNeighbor], 1);
                }
            }
        }
    }
    
    *numDeletedVertices2 += maxDegree;
    __syncthreads();

    for(unsigned int edge = graph.srcPtr[maxVertex] + threadIdx.x; edge < graph.srcPtr[maxVertex + 1] ; edge += blockDim.x) {
        unsigned int neighbor = graph.dst[edge];
        vertexDegrees_s2[neighbor] = -1;
    }
    __syncthreads();
}

__device__ void deleteMaxDegreeVertexMirror(CSRGraph graph, INT_OR_SHORT* vertexDegrees_s, INT_OR_SHORT* vertexDegrees_s2, INT_OR_SHORT* vertexDegrees_s3, unsigned int* numDeletedVertices, unsigned int maxVertex) {
    
    INT_OR_SHORT * used = vertexDegrees_s2;
    __shared__ int mirrorsNum;
    __shared__ int mirrors[32];
    int warpIdx =  threadIdx.x / 32;
    int warpLane = threadIdx.x % 32;
    
    for(int i =threadIdx.x ; i<graph.vertexNum ; i+=blockDim.x){
        used[i]= 0;
    }
    
    __syncthreads();

    if(threadIdx.x == 0){
        mirrorsNum = 0;
        used[maxVertex] = 1;
    }
    __syncthreads();
    for(unsigned int edge = graph.srcPtr[maxVertex]+threadIdx.x; edge < graph.srcPtr[maxVertex+1]; edge+=blockDim.x) {
        unsigned int neigh = graph.dst[edge];
        if(vertexDegrees_s[neigh] > 0) {
            used[neigh] = 1;
        }
    }
   
    __syncthreads();
    for(unsigned int edge = graph.srcPtr[maxVertex]+warpIdx; edge < graph.srcPtr[maxVertex+1]; edge+=blockDim.x/32) {
        unsigned int neigh = graph.dst[edge];
        if(vertexDegrees_s[neigh] > 0){
            for(unsigned int edgeN = graph.srcPtr[neigh]+warpLane; edgeN < graph.srcPtr[neigh+1]; edgeN+=32) {
                unsigned int neighNeigh = graph.dst[edgeN];
                if(vertexDegrees_s[neighNeigh] > 0 && ATOMIC_TYPE(atomicCAS)(&used[neighNeigh], 0, 1) == 0) {                    // ATOMIC_TYPE(atomicAdd)(&vertexDegrees_s3[neighNeigh],1);
                    int neighDiff = vertexDegrees_s[maxVertex];
                    for(unsigned int neighNeighEdge = graph.srcPtr[neighNeigh]; neighNeighEdge < graph.srcPtr[neighNeigh+1]; ++neighNeighEdge) {
                        unsigned int neighNeighN = graph.dst[neighNeighEdge];
                        if(vertexDegrees_s[neighNeighN] > 0 && binarySearch(graph.dst, graph.srcPtr[maxVertex], graph.srcPtr[maxVertex+1]-1, neighNeighN)) {
                            neighDiff--;
                        }
                    }
                    bool isMirror = true;
                    for(unsigned int edge2 = graph.srcPtr[maxVertex]; edge2 < graph.srcPtr[maxVertex+1]; ++edge2) {
                        unsigned int neigh2 = graph.dst[edge2];
                        if(vertexDegrees_s[neigh2] > 0 && !binarySearch(graph.dst, graph.srcPtr[neighNeigh], graph.srcPtr[neighNeigh+1]-1, neigh2)) {
                            int conSize = 0;
                            for(unsigned int edgeN2 = graph.srcPtr[neigh2]; edgeN2 < graph.srcPtr[neigh2+1]; ++edgeN2) {
                                unsigned int neighNeigh2 = graph.dst[edgeN2];
                                if(vertexDegrees_s[neighNeigh2] > 0 &&!binarySearch(graph.dst, graph.srcPtr[neighNeigh], graph.srcPtr[neighNeigh+1]-1, neighNeigh2) && binarySearch(graph.dst, graph.srcPtr[maxVertex], graph.srcPtr[maxVertex+1]-1, neighNeigh2)) {
                                    conSize++;
                                }
                                
                            }
                            if(conSize != neighDiff -1) {
                                isMirror = false;
                                break;
                            }
                        }
                    }
                    if(isMirror){
                        int mirrorIdx = atomicAdd(&mirrorsNum,1);
                        if(mirrorIdx < 32) {
                            mirrors[mirrorIdx] = neighNeigh;
                        }
                        
                    }
                }
            }
        }
    }
    __syncthreads();

    if(threadIdx.x == 0 && mirrorsNum > 32) 
        mirrorsNum = 32;
    __syncthreads();

    if(threadIdx.x == 0){
        vertexDegrees_s[maxVertex] = -1;      
    }
    for(int i = threadIdx.x; i < mirrorsNum; i += blockDim.x) {
            vertexDegrees_s[mirrors[i]] = -1;
        }
    ++(*numDeletedVertices);
    (*numDeletedVertices) += mirrorsNum;

    __syncthreads(); 

    for(unsigned int edge = graph.srcPtr[maxVertex] + threadIdx.x; edge < graph.srcPtr[maxVertex + 1]; edge += blockDim.x) {
        unsigned int neighbor = graph.dst[edge];
        if(vertexDegrees_s[neighbor] > 0) {
            --vertexDegrees_s[neighbor];
        }
    }
    __syncthreads();
    for(int i = 0 ; i < mirrorsNum ; ++i){
        unsigned int mirror = mirrors[i];
        for(unsigned int edge = graph.srcPtr[mirror] + threadIdx.x; edge < graph.srcPtr[mirror + 1]; edge += blockDim.x) {
            unsigned int neighbor = graph.dst[edge];
            if(vertexDegrees_s[neighbor] > 0) {
                --vertexDegrees_s[neighbor];
            }
        }
    }
    
}
__device__ void deleteMaxDegreeVertex(CSRGraph graph, INT_OR_SHORT* vertexDegrees_s, unsigned int* numDeletedVertices, unsigned int maxVertex) {

    if(threadIdx.x == 0){
        vertexDegrees_s[maxVertex] = -1;
    }
    ++(*numDeletedVertices);

    __syncthreads(); 

    for(unsigned int edge = graph.srcPtr[maxVertex] + threadIdx.x; edge < graph.srcPtr[maxVertex + 1]; edge += blockDim.x) {
        unsigned int neighbor = graph.dst[edge];
        if(vertexDegrees_s[neighbor] > 0) {
            --vertexDegrees_s[neighbor];
        }
    }
    __syncthreads();
}
__device__ unsigned int leafReductionRule(unsigned int vertexNum, INT_OR_SHORT *vertexDegrees_s, CSRGraph graph, INT_OR_SHORT* shared_mem, unsigned int left, unsigned int right) {

    __shared__ unsigned int numberDeleted;
    __shared__ bool graphHasChanged;

    volatile INT_OR_SHORT * markedForDeletion = shared_mem;
    if (threadIdx.x==0){
        numberDeleted = 0;
    }
    unsigned int start = threadIdx.x + left;
    do{
        volatile INT_OR_SHORT * vertexDegrees_v = vertexDegrees_s;
        __syncthreads();
                
        for (unsigned int vertex = start ; vertex < right+1; vertex += blockDim.x){
            markedForDeletion[vertex] = 0;
        }
        if (threadIdx.x==0){
            graphHasChanged = false;
        }
        
        __syncthreads();

        for (unsigned int vertex = start ; vertex < right+1; vertex+=blockDim.x){
            INT_OR_SHORT degree = vertexDegrees_v[vertex];
            if (degree == 1){
                for(unsigned int edge = graph.srcPtr[vertex] ; edge < graph.srcPtr[vertex + 1]; ++edge) {
                    unsigned int neighbor = graph.dst[edge];
                    INT_OR_SHORT neighborDegree = vertexDegrees_v[neighbor];
                    if(neighborDegree>0){
                        if(neighborDegree > 1 || (neighborDegree == 1 && neighbor<vertex)) {
                            markedForDeletion[neighbor]=1;
                        }
                        break;
                    }
                }
            }
        }
        
        __syncthreads();
        
        for (unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x){
            if(markedForDeletion[vertex]){ 
                graphHasChanged = true;
                vertexDegrees_v[vertex] = -1;
                atomicAdd(&numberDeleted,1);
            }
        }
        
        __syncthreads();
        
        for (unsigned int vertex = start ; vertex < right+1; vertex+=blockDim.x){
            if(markedForDeletion[vertex]){ 
                for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex + 1]; edge++){
                    unsigned int neighbor = graph.dst[edge];
                    if (vertexDegrees_v[neighbor] > 0){
                        ATOMIC_TYPE(atomicSub)(&vertexDegrees_s[neighbor],1);
                    }
                }
            }
        }
    
    }while(graphHasChanged);

    __syncthreads();

    return numberDeleted;
}

__device__ unsigned int cycleReductionRule(unsigned int vertexNum, INT_OR_SHORT *vertexDegrees_s, CSRGraph graph, INT_OR_SHORT * shared_mem, unsigned int left, unsigned int right) {
    __shared__ unsigned int numberDeleted;
    if(threadIdx.x == 0) {
        numberDeleted = 0;
    }
    volatile INT_OR_SHORT * markedForDeletion = shared_mem;
    INT_OR_SHORT * vertexDegrees_v = vertexDegrees_s;
    unsigned int start = threadIdx.x + left;
    for (unsigned int vertex = start; vertex < right+1; vertex += blockDim.x){
        markedForDeletion[vertex] = 0;
    }
    __syncthreads();

    for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
        INT_OR_SHORT degree = vertexDegrees_v[vertex];
        if(degree != 2) {
            continue;
        }
        bool secondFound = false;
        bool big_brother = false;
        unsigned int last;
        unsigned int second;
        for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
            unsigned int neigh = graph.dst[edge];
            if(vertexDegrees_v[neigh]>0) {
                if(neigh<vertex) {
                    big_brother = true;
                    break;
                }
                if(secondFound) {
                    last = neigh;
                    break;
                } else {
                    secondFound = true;
                    second = neigh;
                }
            }
        }

        if(big_brother) {
            continue;
        }
        
        if(vertexDegrees_v[last] != 2) {
                continue;
        }

        unsigned int first = vertex;
        bool isCycle = true;
        bool done = false;

        while(isCycle) {
            if (vertexDegrees_v[second] != 2) {
                break;
            }
            for(unsigned int edge=graph.srcPtr[second]; edge<graph.srcPtr[second+1]; ++edge) {
                unsigned int neigh = graph.dst[edge];
                if(neigh!=first && vertexDegrees_v[neigh]>0) {
                    if(neigh<vertex || vertexDegrees_v[neigh] != 2) {
                        isCycle = false;
                        break;
                    } else if (neigh!=last) {
                        first = second;
                        second = neigh;
                        break;
                    } else {
                        done = true;
                        break;
                    }
                }
            }
            if(done) {
                markedForDeletion[vertex] = 1;
                unsigned int pointer = vertex;
                unsigned int prev = last;
                unsigned int cycleSize = 1;
                while(pointer!=last) {
                    ++cycleSize;
                    for(unsigned int e = graph.srcPtr[pointer]; e<graph.srcPtr[pointer+1]; ++e) {
                        unsigned int n = graph.dst[e];
                        if(n!=prev && vertexDegrees_v[n]>0) {
                            markedForDeletion[n] = 1;
                            prev = pointer;
                            pointer = n;
                            break;
                        }
                    }
                }
                atomicAdd(&numberDeleted,(cycleSize+1)/2);
                // For Debugging Purposes
                //printf("Cycle Size: %d\n",cycleSize);
                break;
            }
        }
    }
    __syncthreads();
   
    for (unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
        if(markedForDeletion[vertex]) { 
            vertexDegrees_v[vertex] = -1;
        }
    }

   __syncthreads();
   return numberDeleted;
}

__device__ unsigned int cliqueReductionRule(unsigned int vertexNum, INT_OR_SHORT* vertexDegrees_s, CSRGraph graph, INT_OR_SHORT * shared_mem, unsigned int left, unsigned int right) {
    __shared__ unsigned int numberDeleted;
    if(threadIdx.x == 0) {
        numberDeleted = 0;
    }
    volatile INT_OR_SHORT * markedForDeletion = shared_mem;
    volatile INT_OR_SHORT * vertexDegrees_v = vertexDegrees_s;
    unsigned int start = threadIdx.x + left;
    for (unsigned int vertex = start; vertex < right+1; vertex += blockDim.x){
        markedForDeletion[vertex] = 0;
    }
    __syncthreads();
    
    for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
        INT_OR_SHORT degree = vertexDegrees_v[vertex];
        unsigned int k = degree+1;
        if(degree>2) {
            bool inClique = true;
            for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                unsigned int neigh = graph.dst[edge];
                if(vertexDegrees_v[neigh]>0) {
                    if(neigh<vertex || vertexDegrees_v[neigh]!=k-1) {
                        inClique = false;
                        break;
                    }
                }
            }
            if(inClique) {
                for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                    unsigned int neigh = graph.dst[edge];

                    if(vertexDegrees_v[neigh]>0) {
                        for(unsigned int edgeN = graph.srcPtr[neigh]; edgeN<graph.srcPtr[neigh+1]; ++edgeN) {
                            unsigned int neighN = graph.dst[edgeN];

                            if(vertexDegrees_v[neighN]>0 && neighN!=vertex) {
                                bool found = false;
                                for(unsigned int edgeNN = graph.srcPtr[vertex]; edgeNN<graph.srcPtr[vertex+1]; ++edgeNN) {
                                    unsigned int neighNN = graph.dst[edgeNN];
                                    if(vertexDegrees_v[neighNN]>0 && neighN==neighNN) {
                                        found  = true;
                                        break;
                                    }
                                }
                                if(!found) {
                                    inClique = false;
                                    break;
                                }
                            }
                        }
                        if(!inClique) {
                            break;
                        }
                    }
                }   
            }
            if(inClique) {
                atomicAdd(&numberDeleted,k-1);
                markedForDeletion[vertex] = 1;
                for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                    unsigned int neigh = graph.dst[edge];
                    if (vertexDegrees_v[neigh]>0) {
                        markedForDeletion[neigh] = 1;
                    }
                }
                // For Debugging Purposes
                //printf("Clique Size: %d\n",k);
            }
        }
    }
    __syncthreads();

    for (unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
        if(markedForDeletion[vertex]) { 
            vertexDegrees_v[vertex] = -1;
        }
    }

   __syncthreads();
   return numberDeleted;
}
__device__ unsigned int inducedCliqueReductionRule(unsigned int vertexNum, INT_OR_SHORT* vertexDegrees_s, CSRGraph graph, INT_OR_SHORT * shared_mem, unsigned int left, unsigned int right) {
    __shared__ unsigned int numberDeleted;
    // __shared__ bool graphHasChanged;
    if(threadIdx.x == 0) {
        numberDeleted = 0;
    }
    volatile INT_OR_SHORT * markedForDeletion = shared_mem;
    volatile INT_OR_SHORT * vertexDegrees_v = vertexDegrees_s;
    unsigned int start = threadIdx.x + left;
    for (unsigned int vertex = start; vertex < right+1; vertex += blockDim.x) {
        markedForDeletion[vertex] = 0;
    }
    // do {
        __syncthreads();
        // if (threadIdx.x==0){
        //         graphHasChanged = false;
        // }
        // __syncthreads();

        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
            INT_OR_SHORT degree = vertexDegrees_v[vertex];
            unsigned int k = degree+1;
            if(degree>2) {
                bool inClique = true;
                for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                    unsigned int neigh = graph.dst[edge];
                    if(vertexDegrees_v[neigh]>0) {
                        if (vertexDegrees_v[neigh]<(k-1) || (neigh<vertex && vertexDegrees_v[neigh]==k-1)) {
                            inClique = false;
                            break;
                        }
                    }
                }
                if(inClique) {
                    for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                        unsigned int neigh = graph.dst[edge];
                        if(vertexDegrees_v[neigh]>0) {
                            for(unsigned int edgeN = graph.srcPtr[vertex]; edgeN<graph.srcPtr[vertex + 1]; ++edgeN){
                                unsigned int neighN = graph.dst[edgeN];
                                if(vertexDegrees_v[neighN]>0 && neighN!=neigh){
                                    if(!binarySearch(graph.dst, graph.srcPtr[neighN], graph.srcPtr[neighN + 1]-1, neigh)){
                                        inClique = false;
                                        break;
                                    }
                                }
                            }
                        }
                        if(!inClique) {
                            break;
                        }
                    }
                }
                if(inClique) {
                    for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                        unsigned int neigh = graph.dst[edge];                    
                        if (vertexDegrees_v[neigh]>0) {
                            markedForDeletion[neigh] = 1;
                        }
                    }
                    // For Debugging Purposes
                    // printf("Induced Clique Size: %d\n",k);
                }
            }
        }
        __syncthreads();
        
        for (unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x){
            if(markedForDeletion[vertex]){
                // graphHasChanged = true;
                vertexDegrees_v[vertex] = -1;
                atomicAdd(&numberDeleted,1);
            }
        }
        __syncthreads();
       
        for (unsigned int vertex = start ; vertex < right+1; vertex+=blockDim.x){
            if(markedForDeletion[vertex]){
                for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex + 1]; edge++){
                    unsigned int neighbor = graph.dst[edge];
                    if (vertexDegrees_v[neighbor] > 0){
                        ATOMIC_TYPE(atomicSub)(&vertexDegrees_s[neighbor],1);
                    }
                }
                markedForDeletion[vertex] = 0;
            }
        }
    // } while(graphHasChanged);
    __syncthreads();

    return numberDeleted;
}

__device__ unsigned int DominanceRule(unsigned int vertexNum, INT_OR_SHORT* vertexDegrees_s, CSRGraph graph, INT_OR_SHORT * shared_mem, unsigned int left, unsigned int right) {
    __shared__ unsigned int numberDeleted;
    // __shared__ bool graphHasChanged;
    if(threadIdx.x == 0) {
        numberDeleted = 0;
    }
    volatile INT_OR_SHORT * markedForDeletion = shared_mem;
    volatile INT_OR_SHORT * vertexDegrees_v = vertexDegrees_s;
    unsigned int start = threadIdx.x + left;
    for (unsigned int vertex = start; vertex < right+1; vertex += blockDim.x) {
        markedForDeletion[vertex] = 0;
    }
    // do {
        __syncthreads();
        // if (threadIdx.x==0){
        //         graphHasChanged = false;
        // }
        // __syncthreads();

        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
            INT_OR_SHORT degree = vertexDegrees_v[vertex];
            if(degree>2) {
                bool dominating = false;
                for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                    unsigned int neigh = graph.dst[edge];
                    if(vertexDegrees_v[neigh] > 0 && (vertexDegrees_v[neigh]<degree || (vertex < neigh && vertexDegrees_v[neigh]==degree))) {
                        // check if vertex dominates neigh
                        dominating = true;
                        for(unsigned int edgeN = graph.srcPtr[neigh]; edgeN<graph.srcPtr[neigh + 1]; ++edgeN){
                            unsigned int neighN = graph.dst[edgeN];
                            if(vertexDegrees_v[neighN]>0 && neighN!=vertex){
                                if(!binarySearch(graph.dst, graph.srcPtr[vertex], graph.srcPtr[vertex + 1]-1, neighN)){
                                    dominating = false;
                                    break;
                                }
                            }
                        }
                        if(dominating){
                            markedForDeletion[vertex] = 1;
                            break;
                        }
                    }
                }
                
            }
        }
        __syncthreads();
        
        for (unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x){
            if(markedForDeletion[vertex]){
                // graphHasChanged = true;
                vertexDegrees_v[vertex] = -1;
                atomicAdd(&numberDeleted,1);
            }
        }
        __syncthreads();
       
        for (unsigned int vertex = start ; vertex < right+1; vertex+=blockDim.x){
            if(markedForDeletion[vertex]){
                for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex + 1]; edge++){
                    unsigned int neighbor = graph.dst[edge];
                    if (vertexDegrees_v[neighbor] > 0){
                        ATOMIC_TYPE(atomicSub)(&vertexDegrees_s[neighbor],1);
                    }
                }
                markedForDeletion[vertex] = 0;
            }
        }
    // }  while(graphHasChanged);
    __syncthreads();

    return numberDeleted;
}
__device__ unsigned int unconfinedVertexRule(unsigned int vertexNum, INT_OR_SHORT *vertexDegrees_s, CSRGraph graph, INT_OR_SHORT *sets, unsigned int left, unsigned int right)
{
    __shared__ unsigned int numberDeleted;
    // __shared__ bool graphHasChanged;
    __shared__ int setIdx;
    __shared__ int vertexToAdd;
    __shared__ unsigned int neighDiff;
    __shared__ unsigned int minNeighDiff;
    __shared__ unsigned int intersectionSize;
    __shared__ int minU;
    __shared__ bool found; 

    if (threadIdx.x == 0)
    {
        numberDeleted = 0;
    }

    volatile INT_OR_SHORT *vertexDegrees_v = vertexDegrees_s;

    int setSize = vertexNum;

    for (unsigned int i = threadIdx.x; i < vertexNum; i += blockDim.x)
    {
        sets[i] = -1;
    }

    // do
    // {
        __syncthreads();

        // if (threadIdx.x == 0)
        // {
        //     graphHasChanged = false;
        // }
        // __syncthreads();

        for (unsigned int vertex = left; vertex < right + 1; ++vertex)
        {
            INT_OR_SHORT degree = vertexDegrees_v[vertex];

            if (degree <= 2)
            {
                continue;
            }

            if (threadIdx.x == 0)
            {
                sets[0] = vertex;
                setIdx = 1;
            }
            __syncthreads();

            while (true)
            {
                if (threadIdx.x == 0)
                {
                    minU = -1;
                    minNeighDiff = (unsigned int)__INT_MAX__;
                    found = false;
                }
                __syncthreads();

                for (int j = 0; j < setIdx && !found; ++j)
                {
                    INT_OR_SHORT v = sets[j];
                    if (v == -1)
                        continue;

                    for (int edgeV = graph.srcPtr[v]; edgeV < graph.srcPtr[v + 1] && !found; ++edgeV)
                    {
                        unsigned int U = graph.dst[edgeV];
                        if (vertexDegrees_v[U] <= 0)
                        {
                            continue;
                        }

                        if (threadIdx.x == 0)
                        {
                            intersectionSize = 0;
                        }
                        __syncthreads();

                        for (unsigned int edge = graph.srcPtr[U] + threadIdx.x; edge < graph.srcPtr[U + 1]; edge += blockDim.x)
                        {
                            unsigned int neighU = graph.dst[edge];
                            if (vertexDegrees_v[neighU] <= 0)
                            {
                                continue;
                            }
                            for (int i = 0; i < setIdx; ++i)
                            {
                                if (sets[i] == neighU)
                                {
                                    atomicAdd(&intersectionSize, 1);
                                    break;
                                }
                            }
                        }
                        __syncthreads();

                        if (intersectionSize == 1)
                        {
                            if (threadIdx.x == 0)
                            {
                                neighDiff = 0;
                                vertexToAdd = -1;
                            }
                            __syncthreads();

                            for (unsigned int edge = graph.srcPtr[U] + threadIdx.x; edge < graph.srcPtr[U + 1]; edge += blockDim.x)
                            {
                                unsigned int neighU = graph.dst[edge];
                                if (vertexDegrees_v[neighU] <= 0)
                                {
                                    continue;
                                }
                                int f = 0;
                                for (int setV = 0; setV < setIdx; ++setV)
                                {
                                    INT_OR_SHORT vertexV = sets[setV];
                                    if (vertexV == -1)
                                        continue;
                                    if (neighU == vertexV)
                                    {
                                        f = 1;
                                        break;
                                    }
                                    if (binarySearch(graph.dst, graph.srcPtr[vertexV], graph.srcPtr[vertexV + 1] - 1, neighU))
                                    {
                                        f = 1;
                                        break;
                                    }
                                }
                                if (!f)
                                {
                                    atomicAdd(&neighDiff, 1);
                                    vertexToAdd = neighU; 
                                }
                            }
                            __syncthreads();

                            if (neighDiff <= 1)
                            {
                                if (threadIdx.x == 0)
                                {
                                    minNeighDiff = neighDiff;
                                    minU = U;
                                    found = true; 
                                }
                                __syncthreads();
                            }
                        }
                    }
                }

                if (minU == -1)
                {
                    break;
                }

                if (threadIdx.x == 0)
                {
                    neighDiff = 0;
                    vertexToAdd = -1;
                }
                __syncthreads();

                for (unsigned int edge = graph.srcPtr[minU] + threadIdx.x; edge < graph.srcPtr[minU + 1]; edge += blockDim.x)
                {
                    unsigned int neighU = graph.dst[edge];
                    if (vertexDegrees_v[neighU] <= 0)
                    {
                        continue;
                    }
                    int f = 0;
                    for (int setV = 0; setV < setIdx; ++setV)
                    {
                        INT_OR_SHORT vertexV = sets[setV];
                        if (vertexV == -1)
                            continue;
                        if (neighU == vertexV)
                        {
                            f = 1;
                            break;
                        }
                        if (binarySearch(graph.dst, graph.srcPtr[vertexV], graph.srcPtr[vertexV + 1] - 1, neighU))
                        {
                            f = 1;
                            break;
                        }
                    }
                    if (!f)
                    {
                        atomicAdd(&neighDiff, 1);
                        vertexToAdd = neighU;
                    }
                }
                __syncthreads();

                if (vertexToAdd == -1)
                {
                    if (threadIdx.x == 0)
                    {
                        // graphHasChanged = true;
                        vertexDegrees_v[vertex] = -1;
                        numberDeleted++;
                    }
                    __syncthreads();

                    for (unsigned int edge = graph.srcPtr[vertex] + threadIdx.x; edge < graph.srcPtr[vertex + 1]; edge += blockDim.x)
                    {
                        unsigned int neighbor = graph.dst[edge];
                        if (vertexDegrees_v[neighbor] > 0)
                        {
                            ATOMIC_TYPE(atomicSub)(&vertexDegrees_s[neighbor], 1);
                        }
                    }
                    __syncthreads();
                    break;
                }
                else
                {
                    if (setIdx >= setSize)
                    {
                        break;
                    }
                    else
                    {
                        if (threadIdx.x == 0)
                        {
                            sets[setIdx] = vertexToAdd;
                            setIdx++;
                        }
                        __syncthreads();
                    }
                }
            }
        }

        __syncthreads();
    // } while (graphHasChanged);

    return numberDeleted;
}
__device__ int cliqueLowerBound(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s, INT_OR_SHORT *clique,INT_OR_SHORT *tmp, unsigned int left, unsigned int right)
{
    // prepare the vertices
    __shared__ int lowerBound;
    __shared__ int size_c[32];
    __shared__ int tos[32];
    int warpIdx = threadIdx.x/32;
    int warpLane =  threadIdx.x%32;
    if(threadIdx.x == 0){
        lowerBound = 0; 
    }    
    for(int i =   threadIdx.x; i < graph.vertexNum; i += blockDim.x){
        clique[i] = -1;
    }
    __syncthreads();

    for(int vertex = left; vertex < right + 1; ++vertex){

        if(vertexDegrees_s[vertex] <= 0){
            continue;
        }
        unsigned int to = vertex, max = 0;
        int anotherNeighbor = 0;

        for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex + 1]; ++edge){
            unsigned int neigh = graph.dst[edge];
            if(vertexDegrees_s[neigh] > 0 && clique[neigh] != -1){
                tmp[clique[neigh]] = 0;
            }
        }
        __syncthreads();
       for(unsigned int edge = graph.srcPtr[vertex]+warpIdx; edge < graph.srcPtr[vertex + 1]; edge += blockDim.x/32){
            unsigned int neigh = graph.dst[edge];
            if(vertexDegrees_s[neigh] > 0 && clique[neigh] != -1){
                if(warpLane == 0)
                    size_c[warpIdx] = 0;
                __syncwarp();    
                int c = clique[neigh];
                if (c < (int)left || c > (int)right) continue;
                int notFirst = 0;                                        
                for(unsigned int edge2 = graph.srcPtr[vertex]+warpLane; edge2 < graph.srcPtr[vertex + 1]; edge2 += 32){
                    unsigned int neigh2 = graph.dst[edge2];
                    if(vertexDegrees_s[neigh2] > 0 && clique[neigh2] == c ){
                        if(neigh2 < neigh)
                            notFirst = 1;                                
                        else
                            atomicAdd(&size_c[warpIdx],1);
                    }
                }
                __syncwarp();
                if(__any_sync(0xffffffff, notFirst))                     
                    continue;
				// atomicAdd(&tmp[c], 1);
                if(warpLane == 0){
                    if(size_c[warpIdx] == 0){
                        //ATOMIC_TYPE(atomicAdd)(&tmp[c], 1);
                        tmp[c]++;
                    }
                    else{
                        tmp[c] += size_c[warpIdx];
                        // ATOMIC_TYPE(atomicAdd)(&tmp[c], anotherNeighbor);    
                    }
                }    
                __syncwarp();                                           
                if(warpLane == 0)                                       
                    size_c[warpIdx] = 0;
                __syncwarp();                                           
                for(int i = left+warpLane; i< right + 1; i+=32)
                    if(clique[i]== c)
                        atomicAdd(&size_c[warpIdx],1);
                __syncwarp();        
                if (tmp[c] == size_c[warpIdx] && max < size_c[warpIdx]) {
                    to = c;
                    max = size_c[warpIdx];
                }
                __syncwarp();                                           
            }
        }    
        //reduction to commit global max
        __syncthreads();
        size_c[warpIdx] = max;
        tos[warpIdx] = to;
        __syncthreads();
        if(threadIdx.x == 0) {
            max = size_c[0];
            to = tos[0];
            for(int w = 1; w < blockDim.x/32; ++w){
                if(size_c[w] > max){
                    max = size_c[w];
                    to = tos[w];
                }
            }
            clique[vertex] = to;
            if (to != vertex) 
                lowerBound++;
        }   
        __syncthreads(); 
    }
    
    int lb = lowerBound;                                                
    __syncthreads();                                                 
    return lb;
}
__device__ __forceinline__ INT_OR_SHORT encodeVertex(int v, int sizeOfA,INT_OR_SHORT x) {
    if (v == -1) return (INT_OR_SHORT)0;              
    if (v < sizeOfA) return (INT_OR_SHORT)(v + 1);     
    return (INT_OR_SHORT)(-(v - sizeOfA + 1));        
}

__device__ __forceinline__ int decodeVertex(INT_OR_SHORT enc, int sizeOfA) {
    if (enc == 0) return -1;
    if (enc > 0) return (int)enc - 1;
    return sizeOfA + (int)(-enc) - 1;
}
__device__ __forceinline__  int rawVersion(unsigned int vertex, INT_OR_SHORT n){
    return (vertex >= n) ? vertex - n : vertex;
}

__device__ __forceinline__ INT_OR_SHORT* accessDoubleArray(INT_OR_SHORT* a1, INT_OR_SHORT* a2, unsigned int i, int sizeOfA){
    if(i < sizeOfA )
        return a1;
    return a2;
}

__device__ __forceinline__ INT_OR_SHORT* accessDoubleArrayRawVersion(INT_OR_SHORT* a1, INT_OR_SHORT* a2,  int i, int sizeOfA){
    return accessDoubleArray(a1, a2, i, sizeOfA) + (rawVersion(i, sizeOfA));
}

__device__ void populateWL_kernel(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s,
                                   INT_OR_SHORT* mate1, INT_OR_SHORT* mate2,
                                   INT_OR_SHORT* parent1, INT_OR_SHORT* parent2,
                                   INT_OR_SHORT* source1, INT_OR_SHORT* source2,
                                   INT_OR_SHORT* workList1, INT_OR_SHORT* workList2,
                                   int n, int* wlSize, int sizeOfA)
{
  for (unsigned int v = threadIdx.x; v < (unsigned int)n; v += blockDim.x) {
    if (vertexDegrees_s[rawVersion(v, sizeOfA)] > 0 &&
        decodeVertex(*accessDoubleArrayRawVersion(mate1, mate2, v, sizeOfA), sizeOfA) == -1) {
      int index = atomicAdd(wlSize, 1);
      *accessDoubleArrayRawVersion(workList1, workList2, index, sizeOfA) = encodeVertex((int)v, sizeOfA,0);
      *accessDoubleArrayRawVersion(parent1, parent2, v, sizeOfA) = encodeVertex((int)v, sizeOfA,0);
      *accessDoubleArrayRawVersion(source1, source2, v, sizeOfA) = encodeVertex((int)v, sizeOfA,0);
    }
  }
}
__device__ void setUp(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s,
                       INT_OR_SHORT* mate1, INT_OR_SHORT* mate2,
                       INT_OR_SHORT* parent1, INT_OR_SHORT* parent2,
                       INT_OR_SHORT* source1, INT_OR_SHORT* source2,
                       INT_OR_SHORT* workList1, INT_OR_SHORT* workList2,
                       INT_OR_SHORT* endPoint1, INT_OR_SHORT* endPoint2,
                       int n, int* wlSize, int* nextWlSize, int sizeOfA)
{
  if (threadIdx.x == 0) {
    *wlSize = 0;
    *nextWlSize = 0;
  }
  for (unsigned int i = threadIdx.x; i < (unsigned int)sizeOfA; i += blockDim.x) {
    endPoint1[i] = 0; endPoint2[i] = 0;
    parent1[i] = 0;   parent2[i] = 0;
    source1[i] = 0;   source2[i] = 0;
  }
  __syncthreads();
  populateWL_kernel(graph, vertexDegrees_s, mate1, mate2, parent1, parent2, source1, source2, workList1, workList2, n, wlSize, sizeOfA);
  __syncthreads();
}
__device__ void levelOne_kernel(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s, int* wlSize,
                                 INT_OR_SHORT* workList1, INT_OR_SHORT* workList2,
                                 INT_OR_SHORT* source1, INT_OR_SHORT* source2,
                                 INT_OR_SHORT* endPoint1, INT_OR_SHORT* endPoint2,
                                 INT_OR_SHORT* mate1, INT_OR_SHORT* mate2,
                                 INT_OR_SHORT* parent1, INT_OR_SHORT* parent2,
                                 int* nextWlSize,
                                 INT_OR_SHORT* nextWorkList1, INT_OR_SHORT* nextWorkList2,
                                 int sizeOfA, int startIndexOfB, int* apFound)
{
  for (unsigned int i = threadIdx.x; i < (*wlSize); i += blockDim.x) {
    int beg, end, v, src_v, mateOf_v;
    v = decodeVertex(*accessDoubleArrayRawVersion(workList1, workList2, i, sizeOfA), sizeOfA);
    src_v = decodeVertex(ATOMIC_TYPE(atomicAdd)(accessDoubleArrayRawVersion(source1, source2, v, sizeOfA), 0), sizeOfA);
    mateOf_v = decodeVertex(*accessDoubleArrayRawVersion(mate1, mate2, v, sizeOfA), sizeOfA);

    if (decodeVertex(ATOMIC_TYPE(atomicAdd)(accessDoubleArrayRawVersion(endPoint1, endPoint2, src_v, sizeOfA), 0), sizeOfA) == -1) {
      int v_raw = rawVersion(v, sizeOfA);
      beg = graph.srcPtr[v_raw];
      end = graph.srcPtr[v_raw + 1];
      for (unsigned int j = beg; j < end; j++) {
        unsigned int nbr = graph.dst[j];
        nbr = (v < sizeOfA) ? nbr + sizeOfA : nbr;
        if (vertexDegrees_s[rawVersion(nbr, sizeOfA)] > 0) {
          if (mateOf_v != (int)nbr) {
            int src_nbr = decodeVertex(ATOMIC_TYPE(atomicAdd)(accessDoubleArrayRawVersion(source1, source2, nbr, sizeOfA), 0), sizeOfA);
            if (src_nbr != -1) { // potential middle edge of an AP
              if ((src_v < sizeOfA && src_nbr >= startIndexOfB) || (src_v >= startIndexOfB && src_nbr < sizeOfA)) {
                int v1, v2, src_v1, src_v2;
                if (src_v < sizeOfA) {
                  v1 = v; v2 = nbr; src_v1 = src_v; src_v2 = src_nbr;
                } else {
                  v1 = nbr; v2 = v; src_v1 = src_nbr; src_v2 = src_v;
                }
                int mateOfV1 = decodeVertex(*accessDoubleArrayRawVersion(mate1, mate2, v1, sizeOfA), sizeOfA);
                int valToSet1 = (mateOfV1 != -1) ? mateOfV1 : v1;
                if (ATOMIC_TYPE(atomicCAS)(accessDoubleArrayRawVersion(endPoint1, endPoint2, src_v1, sizeOfA), 0, encodeVertex(valToSet1, sizeOfA,0)) == 0) {
                  int mateOfV2 = decodeVertex(*accessDoubleArrayRawVersion(mate1, mate2, v2, sizeOfA), sizeOfA);
                  int valToSet2 = (mateOfV2 != -1) ? mateOfV2 : v2;
                  if (ATOMIC_TYPE(atomicCAS)(accessDoubleArrayRawVersion(endPoint1, endPoint2, src_v2, sizeOfA), 0, encodeVertex(valToSet2, sizeOfA,0)) == 0) {
                    if (decodeVertex(*accessDoubleArrayRawVersion(parent1, parent2, v1, sizeOfA), sizeOfA) != v1) {
                      *accessDoubleArrayRawVersion(parent1, parent2, v1, sizeOfA) = encodeVertex(v2, sizeOfA,0);
                      ATOMIC_TYPE(atomicExch)(accessDoubleArrayRawVersion(endPoint1, endPoint2, src_v2, sizeOfA), encodeVertex(v1, sizeOfA,0));
                    } else {
                      *accessDoubleArrayRawVersion(parent1, parent2, v2, sizeOfA) = encodeVertex(v1, sizeOfA,0);
                      ATOMIC_TYPE(atomicExch)(accessDoubleArrayRawVersion(endPoint1, endPoint2, src_v1, sizeOfA), encodeVertex(v2, sizeOfA,0));
                    }
                    atomicExch(apFound, 1);
                    break;
                  } else {
                    ATOMIC_TYPE(atomicExch)(accessDoubleArrayRawVersion(endPoint1, endPoint2, src_v1, sizeOfA), 0);
                  }
                }
              }
            } else {
              if (ATOMIC_TYPE(atomicCAS)(accessDoubleArrayRawVersion(parent1, parent2, nbr, sizeOfA), 0, encodeVertex(v, sizeOfA,0)) == 0) {
                ATOMIC_TYPE(atomicExch)(accessDoubleArrayRawVersion(source1, source2, nbr, sizeOfA), encodeVertex(src_v, sizeOfA,0));
                int index = atomicAdd(nextWlSize, 1);
                *accessDoubleArrayRawVersion(nextWorkList1, nextWorkList2, index, sizeOfA) = encodeVertex((int)nbr, sizeOfA,0);
              }
            }
          }
        }
      }
    }
  }
}
__device__ void levelTwo_kernel(INT_OR_SHORT *vertexDegrees_s, int* nextWlSize,
                                 INT_OR_SHORT* nextWorkList1, INT_OR_SHORT* nextWorkList2,
                                 INT_OR_SHORT* mate1, INT_OR_SHORT* mate2,
                                 INT_OR_SHORT* source1, INT_OR_SHORT* source2,
                                 INT_OR_SHORT* parent1, INT_OR_SHORT* parent2,
                                 INT_OR_SHORT* endPoint1, INT_OR_SHORT* endPoint2,
                                 int* wlSize,
                                 INT_OR_SHORT* workList1, INT_OR_SHORT* workList2,
                                 int* goAgain, int* apFound, int* totalPathLengths,
                                 int sizeOfA, int startIndexOfB)
{
  for (int i = threadIdx.x; i < (*nextWlSize); i += blockDim.x) {
    int v = decodeVertex(*accessDoubleArrayRawVersion(nextWorkList1, nextWorkList2, i, sizeOfA), sizeOfA);
    int nbr = decodeVertex(*accessDoubleArrayRawVersion(mate1, mate2, v, sizeOfA), sizeOfA);
    if (nbr == -1) continue; // free vertex reached via a non-matching edge; nothing to extend

    if (vertexDegrees_s[rawVersion(nbr, sizeOfA)] > 0) {
      int srcOfNbr = decodeVertex(*accessDoubleArrayRawVersion(source1, source2, nbr, sizeOfA), sizeOfA);
      if (srcOfNbr != -1) {
        int srcOfV = decodeVertex(*accessDoubleArrayRawVersion(source1, source2, v, sizeOfA), sizeOfA);
        if ((srcOfV < sizeOfA && srcOfNbr >= startIndexOfB) || (srcOfV >= startIndexOfB && srcOfNbr < sizeOfA)) {
          int v1, v2;
          if (srcOfV < sizeOfA) { v1 = v; v2 = nbr; } else { v1 = nbr; v2 = v; }
          int srcOfV1 = decodeVertex(*accessDoubleArrayRawVersion(source1, source2, v1, sizeOfA), sizeOfA);
          int srcOfV2 = decodeVertex(*accessDoubleArrayRawVersion(source1, source2, v2, sizeOfA), sizeOfA);
          if (ATOMIC_TYPE(atomicCAS)(accessDoubleArrayRawVersion(endPoint1, endPoint2, srcOfV1, sizeOfA), 0, encodeVertex(v1, sizeOfA,0)) == 0) {
            if (ATOMIC_TYPE(atomicCAS)(accessDoubleArrayRawVersion(endPoint1, endPoint2, srcOfV2, sizeOfA), 0, encodeVertex(v2, sizeOfA,0)) == 0) {
              atomicExch(apFound, 1);
              atomicAdd(totalPathLengths, 1);
            } else {
              *accessDoubleArrayRawVersion(endPoint1, endPoint2, srcOfV1, sizeOfA) = 0;
            }
          }
        }
      } else {
        *accessDoubleArrayRawVersion(parent1, parent2, nbr, sizeOfA) = encodeVertex(v, sizeOfA,0);
        *accessDoubleArrayRawVersion(source1, source2, nbr, sizeOfA) = *accessDoubleArrayRawVersion(source1, source2, v, sizeOfA); // already encoded — plain copy
        atomicExch(goAgain, 1);
        int index = atomicAdd(wlSize, 1);
        *accessDoubleArrayRawVersion(workList1, workList2, index, sizeOfA) = encodeVertex(nbr, sizeOfA,0);
      }
    }
  }
}
__device__ void searchForAP(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s, int n,
                             INT_OR_SHORT* mate1, INT_OR_SHORT* mate2,
                             INT_OR_SHORT* parent1, INT_OR_SHORT* parent2,
                             INT_OR_SHORT* source1, INT_OR_SHORT* source2,
                             INT_OR_SHORT* endPoint1, INT_OR_SHORT* endPoint2,
                             int sizeOfA, int startIndexOfB,
                             int* wlSize, int* nextWlSize,
                             INT_OR_SHORT* workList1, INT_OR_SHORT* workList2,
                             INT_OR_SHORT* nextWorkList1, INT_OR_SHORT* nextWorkList2,
                             int* goAgain, int* apFound, int* totalPathLengths)
{
  setUp(graph, vertexDegrees_s, mate1, mate2, parent1, parent2, source1, source2, workList1, workList2, endPoint1, endPoint2, n, wlSize, nextWlSize, sizeOfA);
  __syncthreads();
  
  if (threadIdx.x == 0)
    *goAgain = 1;
  __syncthreads();

  while (*goAgain) {
    __syncthreads();
    if (threadIdx.x == 0)
      *goAgain = 0;
    __syncthreads();

    if (*wlSize > 0) {
      levelOne_kernel(graph, vertexDegrees_s, wlSize, workList1, workList2, source1, source2, endPoint1, endPoint2, mate1, mate2, parent1, parent2, nextWlSize, nextWorkList1, nextWorkList2, sizeOfA, startIndexOfB, apFound);
    }
    __syncthreads();

    if (threadIdx.x == 0)
      *wlSize = 0;
    __syncthreads();

    if (*nextWlSize > 0) {
      levelTwo_kernel(vertexDegrees_s, nextWlSize, nextWorkList1, nextWorkList2, mate1, mate2, source1, source2, parent1, parent2, endPoint1, endPoint2, wlSize, workList1, workList2, goAgain, apFound, totalPathLengths, sizeOfA, startIndexOfB);
    }
    __syncthreads();

    if (threadIdx.x == 0 && *goAgain)
      *nextWlSize = 0;
    __syncthreads();
  }
}

__device__ void augFromMidToFreevertex(INT_OR_SHORT* source1, INT_OR_SHORT* source2,
                                        INT_OR_SHORT* parent1, INT_OR_SHORT* parent2,
                                        INT_OR_SHORT* endPoint1, INT_OR_SHORT* endPoint2,
                                        INT_OR_SHORT* mate1, INT_OR_SHORT* mate2,
                                        int sizeOfA, int* totalNumPaths, int* totalPathLengths, int n)
{
  for (int i = threadIdx.x; i < n; i += blockDim.x) {
    if (decodeVertex(*accessDoubleArrayRawVersion(source1, source2, i, sizeOfA), sizeOfA) == i) {
      int startVertex = decodeVertex(*accessDoubleArrayRawVersion(endPoint1, endPoint2, i, sizeOfA), sizeOfA);
      if (startVertex != -1) {
        if (decodeVertex(*accessDoubleArrayRawVersion(parent1, parent2, startVertex, sizeOfA), sizeOfA) == startVertex) {
          if (startVertex < sizeOfA) {
            atomicAdd(totalNumPaths, 1);
          }
        } else {
          if (startVertex < sizeOfA) {
            atomicAdd(totalPathLengths, 1);
            atomicAdd(totalNumPaths, 1);
          }
          int v1 = startVertex;
          int v2 = decodeVertex(*accessDoubleArrayRawVersion(parent1, parent2, v1, sizeOfA), sizeOfA);
          while (true) {
            *accessDoubleArrayRawVersion(mate1, mate2, v1, sizeOfA) = encodeVertex(v2, sizeOfA,0);
            *accessDoubleArrayRawVersion(mate1, mate2, v2, sizeOfA) = encodeVertex(v1, sizeOfA,0);
            atomicAdd(totalPathLengths, 1);
            if (decodeVertex(*accessDoubleArrayRawVersion(parent1, parent2, v2, sizeOfA), sizeOfA) == v2) {
              break;
            } else {
              v1 = decodeVertex(*accessDoubleArrayRawVersion(parent1, parent2, v2, sizeOfA), sizeOfA);
              v2 = decodeVertex(*accessDoubleArrayRawVersion(parent1, parent2, v1, sizeOfA), sizeOfA);
              atomicAdd(totalPathLengths, 1);
            }
          }
        }
      }
    }
  }
}
__device__ bool hasHigherPrio(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s, int a, int a1, int deg_a, INT_OR_SHORT* numProcessedNeighbors)
{
  if (a1 == -1)
    return true;
  else {
    int nextOption_a1 = ATOMIC_TYPE(atomicAdd)(&numProcessedNeighbors[a1],0);
    int nextOp_a = numProcessedNeighbors[a];
    int deg_a1 = vertexDegrees_s[a1];
    return ((deg_a < deg_a1 ) || ((deg_a == deg_a1 ) && a < a1));//numProcessed is incremented at each step so if a vertex initially have high degree and later not, it will be underflowed
  }
}

__device__ void init_processANodes(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s, int itr, int size, int* repeat,
                                    INT_OR_SHORT* mate1, INT_OR_SHORT* mate2,
                                    INT_OR_SHORT* numProcessedNeighbors,
                                    INT_OR_SHORT* iterationFlag2)
{
  for (int a = threadIdx.x; a < size; a += blockDim.x) {
    if (vertexDegrees_s[a] <= 0)
      continue;
    if (decodeVertex(ATOMIC_TYPE(atomicAdd)(&mate1[a], 0), size) == -1) {
      for (int i = graph.srcPtr[a] + numProcessedNeighbors[a]; i < graph.srcPtr[a + 1]; i++) {
        ATOMIC_TYPE(atomicAdd)(&numProcessedNeighbors[a], 1);
        int bRaw = graph.dst[i];
        if (vertexDegrees_s[bRaw] <= 0)
          continue;
        int curMateOfb = decodeVertex(ATOMIC_TYPE(atomicAdd)(&mate2[bRaw], 0), size);
        bool success = false;
        int myDeg = vertexDegrees_s[a];
        while (hasHigherPrio(graph, vertexDegrees_s, a, curMateOfb, myDeg, numProcessedNeighbors)) {
          INT_OR_SHORT prevValEnc = ATOMIC_TYPE(atomicCAS)(&(mate2[bRaw]), encodeVertex(curMateOfb, size,0), encodeVertex(a, size,0));
          if (prevValEnc == encodeVertex(curMateOfb, size,0)) {
            success = true;
            break;
          } else {
            curMateOfb = decodeVertex(prevValEnc, size);
          }
        }
        if (success) {
          ATOMIC_TYPE(atomicExch)(&iterationFlag2[bRaw], itr);
          if (curMateOfb != -1) {
            ATOMIC_TYPE(atomicExch)(&mate1[curMateOfb], 0);
            atomicExch(repeat, 1);
          }
          break;
        }
      }
    }
  }
}

__device__ void init_processBNodes(INT_OR_SHORT *vertexDegrees_s, int itr, int sizeOfB, int startIndexOfB,
                                    INT_OR_SHORT* iterationFlag2, INT_OR_SHORT* mate1, INT_OR_SHORT* mate2)
{
  for (int id = threadIdx.x; id < sizeOfB; id += blockDim.x) {
    int b = startIndexOfB + id;
    if (vertexDegrees_s[id] <= 0)
      continue;
    if (iterationFlag2[id] == itr) {
      int a = decodeVertex(mate2[id], startIndexOfB); // startIndexOfB == sizeOfA here
      mate1[a] = encodeVertex(b, startIndexOfB,0);
    }
  }
}

__device__ void d_init(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s, int n, int sizeOfA, int sizeOfB, int startIndexOfB,
                        INT_OR_SHORT* mate1, INT_OR_SHORT* mate2,
                        INT_OR_SHORT* numProcessedNeighbors,
                        INT_OR_SHORT* iterationFlag1, INT_OR_SHORT* iterationFlag2)
{
  __shared__ int itr;
  __shared__ int repeat;

  for (int i = threadIdx.x; i < sizeOfA; i += blockDim.x) {
    numProcessedNeighbors[i] = 0;
    iterationFlag1[i] = 0;
    iterationFlag2[i] = 0;
  }
  if (threadIdx.x == 0)
    itr = 0;
  __syncthreads();

  do {
    __syncthreads();
    if (threadIdx.x == 0) {
      repeat = 0;
      itr++;
    }
    __syncthreads();
    init_processANodes(graph, vertexDegrees_s, itr, sizeOfA, &repeat, mate1, mate2, numProcessedNeighbors, iterationFlag2);
    __syncthreads();
    init_processBNodes(vertexDegrees_s, itr, sizeOfB, startIndexOfB, iterationFlag2, mate1, mate2);
    __syncthreads();
  } while (repeat);
}
//mate1 contains mates of A, so they belong to B and mate2 contains mates of B, so they belong to A. Both stores the raw version of the vertex.
__device__ void findMaximumMatching(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s,
                                     INT_OR_SHORT* numProcessedNeighbors,
                                     INT_OR_SHORT* iterationFlag1, INT_OR_SHORT* iterationFlag2,
                                     INT_OR_SHORT* mate1, INT_OR_SHORT* mate2,
                                     INT_OR_SHORT* endPoint1, INT_OR_SHORT* endPoint2,
                                     INT_OR_SHORT* parent1, INT_OR_SHORT* parent2,
                                     INT_OR_SHORT* source1, INT_OR_SHORT* source2,
                                     INT_OR_SHORT* workList1, INT_OR_SHORT* workList2,
                                     INT_OR_SHORT* nextWorkList1, INT_OR_SHORT* nextWorkList2)
{
  __shared__ int wlSize;
  __shared__ int nextWlSize;
  __shared__ int goAgain;
  __shared__ int apFound;
  __shared__ int totalPathLengths;
  __shared__ int totalNumPaths;
  __shared__ int sizeOfA, sizeOfB, startIndexOfB, apSearch_itrCount, n;

  if (threadIdx.x == 0) {
    sizeOfA = graph.vertexNum;
    n = 2 * sizeOfA;
    sizeOfB = sizeOfA;
    startIndexOfB = sizeOfA;
    totalNumPaths = 0;
    totalPathLengths = 0;
  }
  __syncthreads();

  // mate1/mate2 together cover the full doubled [0, n) space
  for (int i = threadIdx.x; i < sizeOfA; i += blockDim.x) {
    mate1[i] = 0;
    mate2[i] = 0;
  }
  __syncthreads();

  // Initialization of matching:
  d_init(graph, vertexDegrees_s, n, sizeOfA, sizeOfB, startIndexOfB, mate1, mate2, numProcessedNeighbors, iterationFlag1, iterationFlag2);
  __syncthreads();

  // AP Search Phase:
  do {
    __syncthreads();
    if (threadIdx.x == 0)
      apFound = 0;
    __syncthreads();

    searchForAP(graph, vertexDegrees_s, n, mate1, mate2, parent1, parent2, source1, source2, endPoint1, endPoint2, sizeOfA, startIndexOfB, &wlSize, &nextWlSize, workList1, workList2, nextWorkList1, nextWorkList2, &goAgain, &apFound, &totalPathLengths);
    
  
    __syncthreads();

    augFromMidToFreevertex(source1, source2, parent1, parent2, endPoint1, endPoint2, mate1, mate2, sizeOfA, &totalNumPaths, &totalPathLengths, n);
    
  
    __syncthreads();
  } while (apFound);
}

__device__ int cycleLowerBound(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s, INT_OR_SHORT* numProcessedNeighbors, INT_OR_SHORT* iterationFlag1, INT_OR_SHORT* iterationFlag2, INT_OR_SHORT* mate1, INT_OR_SHORT* mate2, INT_OR_SHORT* endPoint1, INT_OR_SHORT* endPoint2, INT_OR_SHORT* parent1, INT_OR_SHORT* parent2, INT_OR_SHORT* source1, INT_OR_SHORT* source2, INT_OR_SHORT* workList1, INT_OR_SHORT* workList2, INT_OR_SHORT* nextWorkList1,INT_OR_SHORT* nextWorkList2,unsigned int left, unsigned int right)
{
    __shared__ int lowerBound;
    
    //reset
    for (int i = threadIdx.x; i < graph.vertexNum; i += blockDim.x) {
        numProcessedNeighbors[i] = 0;
        mate1[i] = 0;
        mate2[i] = 0;
        endPoint1[i] = 0;
        endPoint2[i] = 0;
        parent1[i] = 0;
        parent2[i] = 0;
        source1[i] = 0;
        source2[i] = 0;
    }
    INT_OR_SHORT vertexNum = graph.vertexNum;
    __syncthreads();
    
    findMaximumMatching( graph, vertexDegrees_s,
                                      numProcessedNeighbors,
                                      iterationFlag1,  iterationFlag2,
                                      mate1,  mate2,
                                      endPoint1,  endPoint2,
                                      parent1,  parent2,
                                      source1,  source2,
                                      workList1,  workList2,
                                      nextWorkList1,  nextWorkList2);
    __syncthreads();

    if(threadIdx.x == 0){
        lowerBound = 0;
    }                    
    INT_OR_SHORT* id = iterationFlag1;
    for(int i = threadIdx.x; i< graph.vertexNum ; i+=blockDim.x){
        id[i] = -1;
    }             
   
    __syncthreads(); 
     for (int vertex = left + threadIdx.x; vertex <= right; vertex += blockDim.x) {
        if (vertexDegrees_s[vertex] > 0 && id[vertex] < 0) {
            int v = vertex;
            int size = 0;
            bool isSmaller = true;
            do {
                v = decodeVertex(mate2[v], graph.vertexNum);
                if (v < vertex) { isSmaller = false; break; }
                if(v == -1)break;
            } while (v != vertex);
            if (!isSmaller) continue;
            v = vertex;
            do {
                id[v] = vertex;
                v = decodeVertex(mate2[v], graph.vertexNum);
                if(v == -1)break;
                
                size++;
            } while (v != vertex);

            bool isClique = true;
            v = vertex;
            for (int j = 0; j < size; ++j) {
                v = decodeVertex(mate2[v], graph.vertexNum);
                if(v == -1)break;
                
                int num = 0;
                for (unsigned int edge = graph.srcPtr[v]; edge < graph.srcPtr[v+1]; ++edge) {
                    unsigned int neigh = graph.dst[edge];
                    if (vertexDegrees_s[neigh] > 0 && id[neigh] == id[v]) num++;
                }
                if (num != size - 1) { isClique = false; break; }
            }
            if (isClique) atomicAdd(&lowerBound, size - 1);
            else atomicAdd(&lowerBound, (size + 1) / 2);
        }
    }

    __syncthreads();
    return lowerBound;
}     
__device__ unsigned int lpReductionRule(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s, INT_OR_SHORT* iter, INT_OR_SHORT* usedLeft, INT_OR_SHORT* usedRight, INT_OR_SHORT* out, INT_OR_SHORT* in, INT_OR_SHORT* endPoint1, INT_OR_SHORT* endPoint2, INT_OR_SHORT* finishOrder1, INT_OR_SHORT* finishOrder2, INT_OR_SHORT* source1, INT_OR_SHORT* source2, INT_OR_SHORT* queue1, INT_OR_SHORT* queue2, INT_OR_SHORT* nextWorkList1,INT_OR_SHORT* nextWorkList2,unsigned int left, unsigned int right)
{
    __shared__ unsigned int numberDeleted;
    __shared__ int compIdx;
    __shared__ int inserted;
    __shared__ int processed;
    __shared__ bool oppositeCopyNotFound;
    __shared__ int insertedBefore, insertedAfter;

    int vertexNum = graph.vertexNum;
__syncthreads();
    //arrays initialization
    for (int i = threadIdx.x; i < graph.vertexNum; i += blockDim.x) {
        iter[i] = 0;
        out[i] = 0;
        in[i] = 0;
        endPoint1[i] = 0;
        endPoint2[i] = 0;
        finishOrder1[i] = 0;
        finishOrder2[i] = 0;
        source1[i] = 0;
        source2[i] = 0;
    }
    if(threadIdx.x == 0)
        numberDeleted = 0;
    __syncthreads();
  //call matching
    findMaximumMatching(graph, vertexDegrees_s,
                                      iter,
                                      usedLeft,  usedRight,
                                      out,  in,
                                      endPoint1,  endPoint2,
                                      finishOrder1,  finishOrder2,
                                      source1,  source2,
                                      queue1,  queue2,
                                      nextWorkList1,  nextWorkList2);
    
   
    __syncthreads();
  //basic deletion step

for (int vertex = left + threadIdx.x; vertex <= right; vertex += blockDim.x) {
    if (vertexDegrees_s[vertex] <= 0) continue;
    int rootOfL = decodeVertex(source1[vertex], graph.vertexNum);
    int rootOfR = decodeVertex(source2[vertex], graph.vertexNum);
    bool lInZ = (rootOfL != -1) && (rootOfL < graph.vertexNum);
    bool rInZ = (rootOfR != -1) && (rootOfR < graph.vertexNum);

    if (lInZ && !rInZ) {
        for (unsigned int edge1 = graph.srcPtr[vertex]; edge1 < graph.srcPtr[vertex + 1]; edge1++) {
            unsigned int vertexNeighbor = graph.dst[edge1];
            int neighborDegree = ATOMIC_TYPE(atomicExch)(&vertexDegrees_s[vertexNeighbor], -1);
            if (neighborDegree <= 0) continue;
            for (unsigned int edge2 = graph.srcPtr[vertexNeighbor]; edge2 < graph.srcPtr[vertexNeighbor + 1]; edge2++) {
                unsigned int neighbor = graph.dst[edge2];
                if (vertexDegrees_s[neighbor] > 0) {
                    ATOMIC_TYPE(atomicSub)(&vertexDegrees_s[neighbor], 1);
                }
            }
            atomicAdd(&numberDeleted, 1);
        }
        vertexDegrees_s[vertex] = -1;
    }
}
    __syncthreads();
    
  //Kosaraju's algorithm to find SCCs

   if(threadIdx.x == 0)
        compIdx = 0;
    for(int i = threadIdx.x; i< vertexNum; i += blockDim.x){
        iter[i] = 0;
        usedLeft[i] = 0;
        usedRight[i] = 0;
    }
    
    __syncthreads();
    //Kosaraju's Algorithm to find the strongly connected components(SCC). The idea is to perform a DFS on
    //the matched double graph and store the vertices in a stack in their finishing order(phase I)
    //Then perform a BFS on the graph to find the SCCs(phase II). 

    if(threadIdx.x == 0) {
      for (int s = 0; s < vertexNum; s++){
          if (vertexDegrees_s[s] > 0 && !usedLeft[s]) {
              usedLeft[s] = 1;
              inserted = 0;
              *accessDoubleArrayRawVersion(queue1,queue2,inserted,vertexNum)= encodeVertex(s, vertexNum,0);   
              while (inserted >= 0) {
                  int vertex = decodeVertex(*accessDoubleArrayRawVersion(queue1,queue2,inserted,vertexNum), vertexNum);
                  int neighbor = -1;
                  if (vertex < vertexNum) {
                      while (iter[vertex] < graph.srcPtr[vertex + 1] - graph.srcPtr[vertex]) {
                          neighbor = vertexNum + graph.dst[graph.srcPtr[vertex] + iter[vertex]++];
                          if (vertexDegrees_s[neighbor - vertexNum] > 0 && !usedRight[neighbor-vertexNum]) {
                              usedRight[neighbor - vertexNum] = 1;
                              break;
                          }
                          neighbor = -1;
                      }
                  } else if (decodeVertex(in[vertex-vertexNum], graph.vertexNum)>=0 && !usedLeft[decodeVertex(in[vertex-vertexNum], graph.vertexNum)]) {
                      usedLeft[decodeVertex(in[vertex-vertexNum], graph.vertexNum)] = 1;
                      neighbor = decodeVertex(in[vertex-vertexNum], graph.vertexNum);
                  }

                  if (neighbor >= 0) {
                      *accessDoubleArrayRawVersion(queue1,queue2,++inserted,vertexNum) = encodeVertex(neighbor, vertexNum,0);
                  } else {
                      *accessDoubleArrayRawVersion(finishOrder1,finishOrder2,compIdx++,vertexNum) = encodeVertex(vertex, vertexNum,0);
                      inserted--;
                  }
              }
          }
      }
  }
  __syncthreads();
  for(int i = threadIdx.x; i < vertexNum; i += blockDim.x) {
      usedLeft[i] = 0;
      usedRight[i] = 0;
  }
  
  __syncthreads();
  //second deletion step
  for (int i = compIdx - 1 ; i >= 0; i--){
        __syncthreads();
        int vertexFinishOrder = decodeVertex(*accessDoubleArrayRawVersion(finishOrder1,finishOrder2,i,vertexNum), vertexNum);
        if ((vertexFinishOrder>=vertexNum &&!usedRight[vertexFinishOrder-vertexNum]) || (vertexFinishOrder<vertexNum && !usedLeft[vertexFinishOrder])) {
            __syncthreads();
            if(vertexFinishOrder>= vertexNum)
                usedRight[vertexFinishOrder-vertexNum] = 1;
            else
                usedLeft[vertexFinishOrder] = 1;
            __syncthreads();    
            int vertex = vertexFinishOrder;

            if (threadIdx.x == 0) {
                inserted = 0;
                *accessDoubleArrayRawVersion(queue1, queue2, inserted++, vertexNum) = encodeVertex(vertex, vertexNum, 0);
                oppositeCopyNotFound = true;
                insertedBefore = 0;
                insertedAfter = inserted;     
            }
            __syncthreads();

            while (insertedBefore < insertedAfter) {
                for (int idx = insertedBefore + threadIdx.x; idx < insertedAfter; idx += blockDim.x) {
                    int v = decodeVertex(*accessDoubleArrayRawVersion(queue1, queue2, idx, vertexNum), vertexNum);

                    if ((v >= vertexNum && usedLeft[v - vertexNum]) ||
                        (v <  vertexNum && usedRight[v]))
                        oppositeCopyNotFound = false;

                    if (v >= vertexNum) {
                        for (unsigned int edge = graph.srcPtr[v - vertexNum]; edge < graph.srcPtr[v - vertexNum + 1]; ++edge) {
                            unsigned int neigh = graph.dst[edge];
                            if (vertexDegrees_s[neigh] > 0 &&
                                ATOMIC_TYPE(atomicCAS)(&usedLeft[neigh], 0, 1) == 0) {
                                int insertIdx = atomicAdd(&inserted, 1);
                                *accessDoubleArrayRawVersion(queue1, queue2, insertIdx, vertexNum) = encodeVertex(neigh, vertexNum, 0);
                            }
                        }
                    } else {
                        int matedDoubled = decodeVertex(out[v], graph.vertexNum);
                        if (matedDoubled > -1) {
                            int matedRaw = matedDoubled - graph.vertexNum;
                            if (vertexDegrees_s[matedRaw] > 0 &&
                                ATOMIC_TYPE(atomicCAS)(&usedRight[matedRaw], 0, 1) == 0) {
                                int insertIdx = atomicAdd(&inserted, 1);
                                *accessDoubleArrayRawVersion(queue1, queue2, insertIdx, vertexNum) = encodeVertex(matedDoubled, vertexNum, 0);
                            }
                        }
                    }
                }
                __syncthreads();              

                if (threadIdx.x == 0) {
                    insertedBefore = insertedAfter;      
                    insertedAfter = inserted;      
                }
                __syncthreads();
            }
            __syncthreads();
            if (oppositeCopyNotFound) {//delete the vertex and add all its neighbors to the vertex cover
                for (int j = 0; j < inserted; j++) {
                    vertex = decodeVertex(*accessDoubleArrayRawVersion(queue1,queue2,j,vertexNum), vertexNum);
                    if (vertex >= vertexNum) {
                        unsigned int v = vertex - vertexNum;
                        for (unsigned int edge1 = graph.srcPtr[v]; edge1 < graph.srcPtr[v + 1]; edge1++) {
                            unsigned int vertexNeighbor = graph.dst[edge1];

                            
                            int neighborDegree = ATOMIC_TYPE(atomicExch)(&vertexDegrees_s[vertexNeighbor], -1);
                            if (neighborDegree <= 0) continue;

                            for (unsigned int edge2 = graph.srcPtr[vertexNeighbor]; edge2 < graph.srcPtr[vertexNeighbor + 1]; edge2++) {
                                unsigned int neighbor = graph.dst[edge2];
                                if (vertexDegrees_s[neighbor] > 0) {
                                    ATOMIC_TYPE(atomicSub)(&vertexDegrees_s[neighbor], 1);
                                }
                            }
                            atomicAdd(&numberDeleted, 1);
                            vertexDegrees_s[vertexNeighbor] = -1;
                        }
                        vertexDegrees_s[v] = -1;
                    }
                    
                }
            }
    
        }
    }
   __syncthreads();      
  return numberDeleted;
}
__device__ int lpLowerBound(CSRGraph graph, INT_OR_SHORT *vertexDegrees_s,INT_OR_SHORT *reduction, unsigned int left, unsigned int right)
{
    for(int i = threadIdx.x ; i < graph.vertexNum ; i+=blockDim.x){
        if(vertexDegrees_s[i]>0)
            reduction[i] = 1;
        else    
            reduction[i] = 0;
    }
    __syncthreads();
    for (int stride = graph.vertexNum/2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) {
            reduction[threadIdx.x] += reduction[threadIdx.x + stride];
        }
        __syncthreads();
    }    
    int LowerBound = reduction[0];
    return (LowerBound+1)/2;
}

__device__ unsigned int bfsCC_StackOnly(unsigned int vertexNum, INT_OR_SHORT* vertexDegrees_s, CSRGraph graph, INT_OR_SHORT* shared_mem, int arrayIndex, bool compNode, unsigned int minimum_s, unsigned int* numDeletedVertices, Counters* blockCounters, volatile INT_OR_SHORT * stackVertexDegrees, volatile unsigned int * stackNumDeletedVertices, volatile int * stackArrayIndex, volatile bool * stackCompNode, int* stackTop, unsigned int stackSize, unsigned int left, unsigned int right) {

    __shared__ int num_components;
    __shared__ int found_new_level;
    __shared__ bool done;
    __shared__ int select_comp;
    __shared__ bool exceedFlag;
    __shared__ int compSize;
    __shared__ int not_Clique_Cycle;
    __shared__ int compStartingVertexDegree;
    unsigned int parentIndex;
    volatile INT_OR_SHORT* components = shared_mem;
    unsigned int start = threadIdx.x + left;
    
    if (threadIdx.x == 0) {
        done = true;
        num_components = 0;
        exceedFlag = false;
    }
    __syncthreads();

    for(unsigned int vertex = threadIdx.x; vertex < graph.vertexNum; vertex+=blockDim.x) {
        if(vertexDegrees_s[vertex] > 0) {
            components[vertex] = 0;
            done = false;
        } else {
            components[vertex] = -1;
        }
    }
    __syncthreads();
    
    if (done) {return 0;}

    startTime(PUSH_TO_STACK, blockCounters);
    pushStack(vertexNum, (INT_OR_SHORT*)components, numDeletedVertices, arrayIndex, compNode, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, stackCompNode, stackTop, true);
    endTime(PUSH_TO_STACK, blockCounters);
    maxDepth(*stackTop, blockCounters);
    parentIndex = *stackTop;
     __syncthreads();

    do {
        __syncthreads();
        if(threadIdx.x == 0) {
            select_comp = 0;
            compSize = 1;
            not_Clique_Cycle = 0;
            ++num_components;
            done = true;
        }
        __syncthreads();

        for (unsigned int i = start; i<right+1 && !select_comp; i+=blockDim.x) {
            if(components[i] == 0) {
                if(atomicCAS(&select_comp,0,1) == 0) {
                    components[i] = 1;
                    compStartingVertexDegree = vertexDegrees_s[i];
                }
            }
        }
        __syncthreads();

        do {
            __syncthreads();
            if (threadIdx.x == 0) {
                found_new_level = 0;
            }
             __syncthreads();
            for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                if(components[vertex] == 0) {
                    for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex+1]; ++edge) {
                        unsigned int neigh = graph.dst[edge];
                        if (vertexDegrees_s[neigh]>0) {
                            if(components[neigh] == 1) {
                                components[vertex] = 1;
                                atomicAdd(&compSize,1);
                                found_new_level = 1;
                                if (vertexDegrees_s[vertex]!=compStartingVertexDegree) {
                                    not_Clique_Cycle = 1;
                                }
                                break;
                            }
                        }
                    }
                }
            }
            __syncthreads();
        } while (found_new_level);
        
        if (!not_Clique_Cycle) {
            if (compStartingVertexDegree == 2) {
                *numDeletedVertices += (compSize+1)/2;
                if (threadIdx.x == 0) {
                    stackNumDeletedVertices[parentIndex] += (compSize+1)/2;
                    --num_components;
                }
            } else if (compStartingVertexDegree == compSize-1) {
                *numDeletedVertices += compSize-1;
                if (threadIdx.x == 0) {
                    stackNumDeletedVertices[parentIndex] += compSize-1;
                    --num_components;
                }
            } else {
                 __syncthreads();
                if (threadIdx.x == 0) {
                    not_Clique_Cycle = 1;
                }
            }
        }
        __syncthreads();

        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
            if(components[vertex] == 0) {
                done = false;
                break;
            }
        }
        __syncthreads();
        
        if (!not_Clique_Cycle) {
            for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                if(components[vertex] > 0){
                    components[vertex] = -1;
                    vertexDegrees_s[vertex] = -1;
                }
            }
            __syncthreads();
                
            if (!done) {
                continue;
            }
            __syncthreads();

            if (num_components==0) {
                --(*stackTop);
                return 0;
            } else if (num_components==1) {
                (*stackTop) -= 2;
                return num_components;
            }
            __syncthreads();

            break;
        }
        __syncthreads();
        
        if(done && num_components == 1) {
            --(*stackTop);
            return num_components;
        }
        
        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
            if(components[vertex] == 1) {
                components[vertex] = vertexDegrees_s[vertex];
            }
        }
        __syncthreads();
         
        unsigned int numDeletedVertices2 = 0;
        startTime(PUSH_TO_STACK, blockCounters);
        pushStack(vertexNum, (INT_OR_SHORT*)components, &numDeletedVertices2, parentIndex, 1, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, stackCompNode, stackTop, true);
        endTime(PUSH_TO_STACK,blockCounters);
        maxDepth(*stackTop, blockCounters);
        __syncthreads();
        
        if (threadIdx.x==0 && *stackTop==stackSize-1) {
            exceedFlag = true;
        }
        __syncthreads();
        
        if (exceedFlag) {
            *stackTop = parentIndex-1;
            *numDeletedVertices = minimum_s;
            return 0; //no need for this node
        }

        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x){
            if(components[vertex] > 0){
                components[vertex] = -1;
            }
        }
        __syncthreads();

    } while(!done);
    __syncthreads();
    
    if (threadIdx.x==0) {
        done = false;
        #if USE_SHORT_DEGREE
        saveIntInShortArray(&stackVertexDegrees[(long long)parentIndex*(long long)graph.vertexNum+(long long)3], num_components-1);
        #else
        stackVertexDegrees[(long long)parentIndex*(long long)graph.vertexNum+(long long)3] = num_components-1;
        #endif
        if (minimum_s>*numDeletedVertices+num_components) {
            #if USE_SHORT_DEGREE
            saveIntInShortArray(&stackVertexDegrees[(long long)parentIndex*(long long)graph.vertexNum], minimum_s-*numDeletedVertices-num_components+1);
            #else
            stackVertexDegrees[(long long)parentIndex*(long long)graph.vertexNum] = minimum_s-*numDeletedVertices-num_components+1;
            #endif
        } else {
            done = true;
        }
    }
    __syncthreads();
    
    if (done) {
        *stackTop = parentIndex-1;
        *numDeletedVertices = minimum_s;
        return 0; //no need for this node
    }
    __syncthreads();

    return num_components;
}

__device__ unsigned int bfsCC_param_StackOnly(unsigned int vertexNum, INT_OR_SHORT* vertexDegrees_s, CSRGraph graph, INT_OR_SHORT* shared_mem, int arrayIndex, bool compNode, unsigned int minimum_s, unsigned int* numDeletedVertices, Counters* blockCounters, volatile INT_OR_SHORT * stackVertexDegrees, volatile unsigned int * stackNumDeletedVertices, volatile int * stackArrayIndex, volatile bool * stackCompNode, int* stackTop, unsigned int stackSize, unsigned int * k, unsigned int left, unsigned int right) {

    __shared__ int num_components;
    __shared__ int found_new_level;
    __shared__ bool done;
    __shared__ int select_comp;
    __shared__ bool exceedFlag;
    __shared__ int compSize;
    __shared__ int not_Clique_Cycle;
    __shared__ int compStartingVertexDegree;
    unsigned int parentIndex;
    volatile INT_OR_SHORT* components = shared_mem;
    unsigned int start = threadIdx.x + left;
    
    if (threadIdx.x == 0) {
        done = true;
        num_components = 0;
        exceedFlag = false;
    }
    __syncthreads();

    for(unsigned int vertex = threadIdx.x; vertex < graph.vertexNum; vertex+=blockDim.x) {
        if(vertexDegrees_s[vertex] > 0) {
            components[vertex] = 0;
            done = false;
        } else {
            components[vertex] = -1;
        }
    }
    __syncthreads();
    
    if (done) {return 0;}

    startTime(PUSH_TO_STACK, blockCounters);
    pushStack(vertexNum, (INT_OR_SHORT*)components, numDeletedVertices, arrayIndex, compNode, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, stackCompNode, stackTop, true);
    endTime(PUSH_TO_STACK, blockCounters);
    maxDepth(*stackTop, blockCounters);
    parentIndex = *stackTop;
     __syncthreads();

    do {
        __syncthreads();
        if(threadIdx.x == 0) {
            select_comp = 0;
            compSize = 1;
            not_Clique_Cycle = 0;
            ++num_components;
            done = true;
        }
        __syncthreads();

        for (unsigned int i = start; i<right+1 && !select_comp; i+=blockDim.x) {
            if(components[i] == 0) {
                if(atomicCAS(&select_comp,0,1) == 0) {
                    components[i] = 1;
                    compStartingVertexDegree = vertexDegrees_s[i];
                }
            }
        }
        __syncthreads();

        do {
            __syncthreads();
            if (threadIdx.x == 0) {
                found_new_level = 0;
            }
             __syncthreads();
            for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                if(components[vertex] == 0) {
                    for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex+1]; ++edge) {
                        unsigned int neigh = graph.dst[edge];
                        if (vertexDegrees_s[neigh]>0) {
                            if(components[neigh] == 1) {
                                components[vertex] = 1;
                                atomicAdd(&compSize,1);
                                found_new_level = 1;
                                if (vertexDegrees_s[vertex]!=compStartingVertexDegree) {
                                    not_Clique_Cycle = 1;
                                }
                                break;
                            }
                        }
                    }
                }
            }
            __syncthreads();
        } while (found_new_level);
        
        if (!not_Clique_Cycle) {
            if (compStartingVertexDegree == 2) {
                *numDeletedVertices += (compSize+1)/2;
                if (threadIdx.x == 0) {
                    stackNumDeletedVertices[parentIndex] += (compSize+1)/2;
                    --num_components;
                }
            } else if (compStartingVertexDegree == compSize-1) {
                *numDeletedVertices += compSize-1;
                if (threadIdx.x == 0) {
                    stackNumDeletedVertices[parentIndex] += compSize-1;
                    --num_components;
                }
            } else {
                 __syncthreads();
                if (threadIdx.x == 0) {
                    not_Clique_Cycle = 1;
                }
            }
        }
        __syncthreads();

        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
            if(components[vertex] == 0) {
                done = false;
                break;
            }
        }
        __syncthreads();
        
        if (!not_Clique_Cycle) {
            for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                if(components[vertex] > 0){
                    components[vertex] = -1;
                    vertexDegrees_s[vertex] = -1;
                }
            }
            __syncthreads();
                
            if (!done) {
                continue;
            }
            __syncthreads();

            if (num_components==0) {
                --(*stackTop);
                return 0;
            } else if (num_components==1) {
                (*stackTop) -= 2;
                return num_components;
            }
            __syncthreads();

            break;
        }
        __syncthreads();
        
        if(done && num_components == 1) {
            --(*stackTop);
            return num_components;
        }
        
        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
            if(components[vertex] == 1) {
                components[vertex] = vertexDegrees_s[vertex];
            }
        }
        __syncthreads();
         
        unsigned int numDeletedVertices2 = 0;
        startTime(PUSH_TO_STACK, blockCounters);
        pushStack(vertexNum, (INT_OR_SHORT*)components, &numDeletedVertices2, parentIndex, 1, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, stackCompNode, stackTop, true);
        endTime(PUSH_TO_STACK,blockCounters);
        maxDepth(*stackTop, blockCounters);
        __syncthreads();
        
        if (threadIdx.x==0) {
            if (*stackTop==stackSize-1) {
                exceedFlag = true;
            }
            
        }
        __syncthreads();
        
        if (exceedFlag) {
            *stackTop = parentIndex-1;
            *numDeletedVertices = minimum_s;
            return 0; //no need for this node
        }

        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x){
            if(components[vertex] > 0){
                components[vertex] = -1;
            }
        }
        __syncthreads();

    } while(!done);
    __syncthreads();
  
    if (threadIdx.x==0) {  
        for (unsigned int i=1; i<=num_components; ++i) {
            stackNumDeletedVertices[parentIndex] += (int)minimum_s-(int)*numDeletedVertices-i+1;
        }
        done = false;
        #if USE_SHORT_DEGREE
        saveIntInShortArray(&stackVertexDegrees[(long long)parentIndex*(long long)graph.vertexNum+(long long)3], (int)minimum_s-(int)*numDeletedVertices-num_components+1);
        #else
        stackVertexDegrees[(long long)parentIndex*(long long)graph.vertexNum+(long long)3] = (int)minimum_s-(int)*numDeletedVertices-num_components+1;
        #endif
        if (minimum_s>*numDeletedVertices+num_components) {
            #if USE_SHORT_DEGREE
            saveIntInShortArray(&stackVertexDegrees[(long long)parentIndex*(long long)graph.vertexNum], minimum_s-*numDeletedVertices-num_components+1);
            #else
            stackVertexDegrees[(long long)parentIndex*(long long)graph.vertexNum] = minimum_s-*numDeletedVertices-num_components+1;
            #endif
        } else {
            done = true;
        }
    }
    __syncthreads();
    
    if (done) {
        *stackTop = parentIndex-1;
        *numDeletedVertices = minimum_s;
        return 0; //no need for this node
    }
    __syncthreads();

    return num_components;
}

__device__ unsigned int bfs_Hybrid(unsigned int vertexNum, INT_OR_SHORT* vertexDegrees_s, CSRGraph graph, INT_OR_SHORT* shared_mem, int arrayIndex, unsigned int minimum, unsigned int numDeletedVertices, CompArray compArray, WorkList<INT_OR_SHORT> workList, Counters* blockCounters, volatile INT_OR_SHORT * stackVertexDegrees, volatile unsigned int * stackNumDeletedVertices, volatile int * stackArrayIndex, int* stackTop, unsigned int stackSize, unsigned int compArraySize, unsigned int left, unsigned int right) {
    __shared__ int globIndex;
    __shared__ int num_components;
    __shared__ bool exceedFlag;
    __shared__ bool done;
    __shared__ int found_new_level;
    __shared__ int select_comp;
    __shared__ int parentArrayIndex;
    __shared__ int childArrayIndex;
    __shared__ int nextChildIndex;
    __shared__ int compSize;

    volatile INT_OR_SHORT* components = shared_mem;    
    unsigned int start = threadIdx.x + left;
    
    if (threadIdx.x == 0) {
        done = true;
    }
    __syncthreads();

    for(unsigned int vertex = threadIdx.x; vertex < graph.vertexNum; vertex+=blockDim.x) {
        if(vertexDegrees_s[vertex] > 0) {
            components[vertex] = 0;
            done = false;
        } else {
            components[vertex] = -1;
        }
    }
    __syncthreads();

    if (done) {return 0;}
    
    if (threadIdx.x == 0) {
        globIndex = atomicOr((int*)compArray.globalArrayIndex,0);
        num_components = 0;
        exceedFlag = false;
    }
    __syncthreads();

    if (globIndex+3>compArraySize) {return 1;}

    do {
        __syncthreads();
        if(threadIdx.x == 0) {
            select_comp = 0;
            ++num_components;
            compSize = 1;
            done = true;
        }
        __syncthreads();

        for (unsigned int i = start; i<right+1 && !select_comp; i+=blockDim.x) {
            if(components[i] == 0) {
                if(atomicCAS(&select_comp,0,1) == 0) {
                    components[i] = 1;                   
                }
            }
        }
        __syncthreads();

        do {
            __syncthreads();
            if (threadIdx.x == 0) {
                found_new_level = 0;
            }
             __syncthreads();
            for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                if(components[vertex] == 0) {
                    for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex+1]; ++edge) {
                        unsigned int neigh = graph.dst[edge];
                        if (vertexDegrees_s[neigh]>0) {
                            if(components[neigh] == 1) {
                                components[vertex] = 1;
                                atomicAdd(&compSize,1);
                                found_new_level = 1;
                                break;
                            }
                        }
                    }
                }
            }
            __syncthreads();
        } while (found_new_level);

        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
            if(components[vertex] == 0) {
                done = false;
                break;
            }
        }
        __syncthreads();
        
        if (num_components == 1) {
            if (done) {break;}
            __syncthreads();
            if(threadIdx.x == 0) {
                parentArrayIndex = atomicAdd((int*)compArray.globalArrayIndex,3);
                if (parentArrayIndex<compArraySize-2) {
                    compArray.entries[parentArrayIndex].index = arrayIndex;
                    compArray.entries[parentArrayIndex].minimum = numDeletedVertices;
                    compArray.entries[parentArrayIndex].counter = 1;
                    childArrayIndex = parentArrayIndex+1;
                    nextChildIndex = parentArrayIndex+2;
                } else {
                    done = true;
                }
            }
            __syncthreads();
            if (done) {break;}
        } else {
            if (threadIdx.x == 0) {
                childArrayIndex = nextChildIndex;
                nextChildIndex = atomicAdd((int*)compArray.globalArrayIndex,1);
                if (nextChildIndex>=compArraySize) {
                    done = true;
                }
            }
        }
        __syncthreads();
        
        if (threadIdx.x==0) {
            if (!done) {
                atomicAdd((int*)&compArray.entries[parentArrayIndex].counter, 1);
            } else {
                compSize = 0;
            }
        }
        __syncthreads();

        if (done) {
            for(unsigned int vertex = start; vertex<right+1; vertex+=blockDim.x) {
                if(components[vertex] == 1 || components[vertex] == 0) {
                    components[vertex] = vertexDegrees_s[vertex];
                    atomicAdd(&compSize,1);
                }
            }
        } else {
            for(unsigned int vertex = start; vertex<right+1; vertex+=blockDim.x) {
                if(components[vertex] == 1) {
                    components[vertex] = vertexDegrees_s[vertex];
                }
            }
        }
        __syncthreads();

        if(threadIdx.x == 0) {
            compArray.entries[childArrayIndex].index = parentArrayIndex;
            compArray.entries[childArrayIndex].counter = 1;
            if (minimum-numDeletedVertices>num_components) {
                compArray.entries[childArrayIndex].minimum = (compSize-1<minimum-numDeletedVertices-num_components+1)?compSize-1:minimum-numDeletedVertices-num_components+1;
            } else {
                compArray.entries[childArrayIndex].minimum = 0;
                atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum, minimum);
                if (!done) {
                    atomicSub((int*)&compArray.entries[parentArrayIndex].counter, 1);
                }
                done = true;
                ++num_components;
            }
        }
        __syncthreads();
 
        bool enqueueSuccess;
        unsigned int numDeletedVertices2 = 0;
        if(checkThreshold(workList)) {
            startTime(ENQUEUE,blockCounters);
            enqueueSuccess = enqueue((INT_OR_SHORT*)components, workList, vertexNum, &numDeletedVertices2, childArrayIndex);
        } else  {
            enqueueSuccess = false;
        }
        __syncthreads();

        if(!enqueueSuccess) {
            startTime(PUSH_TO_STACK,blockCounters);
            pushStack(vertexNum, (INT_OR_SHORT*)components, &numDeletedVertices2, childArrayIndex, NULL, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, NULL, stackTop, false);        
            endTime(PUSH_TO_STACK,blockCounters);
            maxDepth(*stackTop, blockCounters);
            if (threadIdx.x==0 && *stackTop==stackSize-1) {
                exceedFlag = true;
                compArray.entries[childArrayIndex].minimum = 0;
                atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum, minimum);
                if (!done) {
                    atomicSub((int*)&compArray.entries[parentArrayIndex].counter, 1);
                }
                done = true;
                ++num_components;
            }
            __syncthreads();
            if (exceedFlag) {--(*stackTop);}
        } else {
            endTime(ENQUEUE,blockCounters);
        }
        __syncthreads();

        if (!done) {
            for(unsigned int vertex = threadIdx.x; vertex < graph.vertexNum; vertex+=blockDim.x) {
                if(components[vertex] > 0){
                    components[vertex] = -1;
                }
            }
        }
        __syncthreads();

    } while(!done);

    return num_components;
}

__device__ unsigned int bfsCC_Hybrid(unsigned int vertexNum, INT_OR_SHORT* vertexDegrees_s, CSRGraph graph, INT_OR_SHORT* shared_mem, int arrayIndex, unsigned int minimum, unsigned int * numDeletedVertices, CompArray compArray, WorkList<INT_OR_SHORT> workList, Counters* blockCounters, volatile INT_OR_SHORT * stackVertexDegrees, volatile unsigned int * stackNumDeletedVertices, volatile int * stackArrayIndex, int* stackTop, unsigned int stackSize, unsigned int compArraySize, unsigned int left, unsigned int right, unsigned int* minimum_original, unsigned int* histogram) {
    __shared__ int globIndex;
    __shared__ int num_components;
    __shared__ bool exceedFlag;
    __shared__ bool done;
    __shared__ int found_new_level;
    __shared__ int select_comp;
    __shared__ int parentArrayIndex;
    __shared__ int childArrayIndex;
    __shared__ int nextChildIndex;
    __shared__ int compSize;
    __shared__ int not_Clique_Cycle;
    __shared__ int compStartingVertexDegree;

    volatile INT_OR_SHORT* components = shared_mem;    
    unsigned int start = threadIdx.x + left;
    
    if (threadIdx.x == 0) {
        done = true;
    }
    __syncthreads();

    for(unsigned int vertex = threadIdx.x; vertex < graph.vertexNum; vertex+=blockDim.x) {
        if(vertexDegrees_s[vertex] > 0) {
            components[vertex] = 0;
            done = false;
        } else {
            components[vertex] = -1;
        }
    }
    __syncthreads();

    if (done) {return 0;}
    
    if (threadIdx.x == 0) {
        globIndex = atomicOr((int*)compArray.globalArrayIndex,0);
        num_components = 0;
        exceedFlag = false;
    }
    __syncthreads();

    if (globIndex+3>compArraySize) {return 1;}

    do {
        __syncthreads();
        if(threadIdx.x == 0) {
            select_comp = 0;
            not_Clique_Cycle = 0;
            ++num_components;
            compSize = 1;
            done = true;
        }
        __syncthreads();

        for (unsigned int i = start; i<right+1 && !select_comp; i+=blockDim.x) {
            if(components[i] == 0) {
                if(atomicCAS(&select_comp,0,1) == 0) {
                    components[i] = 1;
                    compStartingVertexDegree = vertexDegrees_s[i];
                }
            }
        }
        __syncthreads();

        do {
            __syncthreads();
            if (threadIdx.x == 0) {
                found_new_level = 0;
            }
             __syncthreads();
            for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                if(components[vertex] == 0) {
                    for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex+1]; ++edge) {
                        unsigned int neigh = graph.dst[edge];
                        if (vertexDegrees_s[neigh]>0) {
                            if(components[neigh] == 1) {
                                components[vertex] = 1;
                                atomicAdd(&compSize,1);
                                found_new_level = 1;
                                if (vertexDegrees_s[vertex]!=compStartingVertexDegree) {
                                    not_Clique_Cycle = 1;
                                }
                                break;
                            }
                        }
                    }
                }
            }
            __syncthreads();
        } while (found_new_level);

        if (!not_Clique_Cycle) {
            if (compStartingVertexDegree == 2) {
                *numDeletedVertices += (compSize+1)/2;
                if (threadIdx.x == 0) {
                    if (num_components>1) {
                        atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum,(compSize+1)/2);  
                    }
                    --num_components;
                }
            } else if (compStartingVertexDegree == compSize-1) {
                *numDeletedVertices += compSize-1;
                if (threadIdx.x == 0) {
                    if (num_components>1) {
                        atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum,compSize-1); 
                    }
                    --num_components;
                }
            } else {
                 __syncthreads();
                if (threadIdx.x == 0) {
                    not_Clique_Cycle = 1;
                }
            }
        }
        __syncthreads();

        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
            if(components[vertex] == 0) {
                done = false;
                break;
            }
        }
        __syncthreads();
        
        if (!not_Clique_Cycle) {
            if (!done) {
                for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                    if(components[vertex] > 0){
                        components[vertex] = -1;
                        vertexDegrees_s[vertex] = -1;
                    }
                }
                __syncthreads();
                continue;
            }

            if (num_components==0) {return 0;} 

            if (threadIdx.x == 0) {
                arrayIndex = parentArrayIndex;
                int numDelVer;
                int counter = atomicSub((int*)&compArray.entries[arrayIndex].counter, 1);
                if (counter==1) {
                    int parentIndex = compArray.entries[arrayIndex].index;
                    atomicAdd((int*)&compArray.entries[parentIndex].minimum, compArray.entries[arrayIndex].minimum);
                    int parentCounter = atomicSub((int*)&compArray.entries[parentIndex].counter, 1);
                    if (parentCounter==1) {
                        arrayIndex = compArray.entries[parentIndex].index;
                        numDelVer = atomicOr((int*)&compArray.entries[parentIndex].minimum,0);
                        while (true) {
                            if (arrayIndex>-1) {
                                atomicMin((int*)&compArray.entries[arrayIndex].minimum, numDelVer);
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
                                numDelVer = atomicOr((int*)&compArray.entries[parentIndex].minimum,0);

                            } else {
                                atomicMin(minimum_original, numDelVer);
                                break;
                            }
                        }
                    }
                }
            }
            __syncthreads();
            return num_components+1; //although num_components maybe 1, it will run on the compArray
        }
        __syncthreads();

        // Histogram
        // if (threadIdx.x == 0) {
        //    atomicAdd(&histogram[compSize-1], 1);
        // }
        // __syncthreads();

        if (num_components == 1) {
            if (done) {break;}
            __syncthreads();
            if(threadIdx.x == 0) {
                parentArrayIndex = atomicAdd((int*)compArray.globalArrayIndex,3);
                if (parentArrayIndex<compArraySize-2) {
                    compArray.entries[parentArrayIndex].index = arrayIndex;
                    compArray.entries[parentArrayIndex].minimum = *numDeletedVertices;
                    compArray.entries[parentArrayIndex].counter = 1;
                    childArrayIndex = parentArrayIndex+1;
                    nextChildIndex = parentArrayIndex+2;
                } else {
                    done = true;
                }
            }
            __syncthreads();
            if (done) {break;}
        } else {
            if (threadIdx.x == 0) {
                childArrayIndex = nextChildIndex;
                nextChildIndex = atomicAdd((int*)compArray.globalArrayIndex,1);
                if (nextChildIndex>=compArraySize) {
                    done = true;
                }
            }
        }
        __syncthreads();
        
        if (threadIdx.x==0) {
            if (!done) {
                atomicAdd((int*)&compArray.entries[parentArrayIndex].counter, 1);
            } else {
                compSize = 0;
            }
        }
        __syncthreads();

        if (done) {
            for(unsigned int vertex = start; vertex<right+1; vertex+=blockDim.x) {
                if(components[vertex] == 1 || components[vertex] == 0) {
                    components[vertex] = vertexDegrees_s[vertex];
                    atomicAdd(&compSize,1);
                }
            }
        } else {
            for(unsigned int vertex = start; vertex<right+1; vertex+=blockDim.x) {
                if(components[vertex] == 1) {
                    components[vertex] = vertexDegrees_s[vertex];
                }
            }
        }
        __syncthreads();

        if(threadIdx.x == 0) {
            compArray.entries[childArrayIndex].index = parentArrayIndex;
            compArray.entries[childArrayIndex].counter = 1;
            if (minimum>*numDeletedVertices+num_components) {
                compArray.entries[childArrayIndex].minimum = -1;
            } else {
                compArray.entries[childArrayIndex].minimum = 0;
                atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum, minimum);
                if (!done) {
                    atomicSub((int*)&compArray.entries[parentArrayIndex].counter, 1);
                }
                done = true;
                ++num_components;
            }
        }
        __syncthreads();

        bool enqueueSuccess;
        unsigned int numDeletedVertices2 = 0;
        if(checkThreshold(workList)) {
            startTime(ENQUEUE,blockCounters);
            enqueueSuccess = enqueue((INT_OR_SHORT*)components, workList, vertexNum, &numDeletedVertices2, childArrayIndex);
        } else  {
            enqueueSuccess = false;
        }
        __syncthreads();

        if(!enqueueSuccess) {
            startTime(PUSH_TO_STACK,blockCounters);
            pushStack(vertexNum, (INT_OR_SHORT*)components, &numDeletedVertices2, childArrayIndex, NULL, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, NULL, stackTop, false);        
            endTime(PUSH_TO_STACK,blockCounters);
            maxDepth(*stackTop, blockCounters);
            if (threadIdx.x==0 && *stackTop==stackSize-1) {
                exceedFlag = true;
                compArray.entries[childArrayIndex].minimum = 0;
                atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum, minimum);
                if (!done) {
                    atomicSub((int*)&compArray.entries[parentArrayIndex].counter, 1);
                }
                done = true;
                ++num_components;
            }
            __syncthreads();
            if (exceedFlag) {--(*stackTop);}
        } else {
            endTime(ENQUEUE,blockCounters);
        }
        __syncthreads();

        if (!done) {
            for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                if(components[vertex] > 0){
                    components[vertex] = -1;
                }
            }
        }
        __syncthreads();

    } while(!done);
    
    __syncthreads();
    
    return num_components;
}

__device__ unsigned int bfsConnectedComp_Hybrid(unsigned int vertexNum, INT_OR_SHORT* vertexDegrees_s, CSRGraph graph, INT_OR_SHORT* shared_mem, int arrayIndex, unsigned int minimum, unsigned int numDeletedVertices, CompArray compArray, WorkList<INT_OR_SHORT> workList, Counters* blockCounters, volatile INT_OR_SHORT * stackVertexDegrees, volatile unsigned int * stackNumDeletedVertices, volatile int * stackArrayIndex, int* stackTop, unsigned int stackSize, unsigned int compArraySize, unsigned int left, unsigned int right) {

    __shared__ int globIndex;
    __shared__ int num_components;
    __shared__ bool exceedFlag;
    __shared__ int select_comp1;
    __shared__ int select_comp2;
    __shared__ int comp1;
    __shared__ int comp2;
    __shared__ bool done;
    __shared__ int found_new_level;
    __shared__ int parentArrayIndex;
    __shared__ int childArrayIndex;
    __shared__ int nextChildIndex;
    __shared__ int compSize;

    volatile INT_OR_SHORT* components = shared_mem;
    unsigned int start = threadIdx.x + left;
    
    if (threadIdx.x == 0) {
        done = true;
    }
    __syncthreads();
    
    for(unsigned int vertex = threadIdx.x; vertex < graph.vertexNum; vertex+=blockDim.x) {
        if(vertexDegrees_s[vertex] > 0) {
            components[vertex] = vertex;
            done = false;
        } else {
            components[vertex] = -1;
        }
    }
    __syncthreads();

    if (done) {return 0;}
    
    if (threadIdx.x == 0) {
        globIndex = atomicOr((int*)compArray.globalArrayIndex,0);
        num_components = 0;
        select_comp1 = 0;
        select_comp2 = 0;
        exceedFlag = false;
    }
    __syncthreads();

    if (globIndex+3>compArraySize) {
        return 1;
    }
    __syncthreads();

    do {
        __syncthreads();
        if (threadIdx.x == 0) {
            found_new_level = 0;
        }
         __syncthreads();
        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
            if(components[vertex]>-1) {
                for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex+1]; ++edge) {
                    unsigned int neigh = graph.dst[edge];
                    if (vertexDegrees_s[neigh]>0) {
                        if(components[neigh] < components[vertex]) {
                            components[vertex] = components[neigh];
                            found_new_level = 1;
                        }
                    }
                }
            }
        }
        __syncthreads();
    } while (found_new_level);
        
    for (unsigned int i = start; i < right+1 && !select_comp1; i+=blockDim.x) {
        if(components[i]>-1) {
            if(atomicCAS(&select_comp1,0,1) == 0) {
                comp1 = components[i];                   
            }
        }
    }
    __syncthreads();

    for (unsigned int i = start; i < right+1 && !select_comp2; i+=blockDim.x) {
        if(components[i]>-1 && components[i] != comp1) {
            if(atomicCAS(&select_comp2,0,1) == 0) {
                comp2 = components[i];                   
            }
        }
    }
    __syncthreads();

    if (threadIdx.x==0 && !select_comp2) {
        done = true;
    }
    __syncthreads();

    if (done) {return 1;}
    __syncthreads();

    if(threadIdx.x == 0) {
        parentArrayIndex = atomicAdd((int*)compArray.globalArrayIndex,3);
        if (parentArrayIndex<compArraySize-2) {
            compArray.entries[parentArrayIndex].index = arrayIndex;
            compArray.entries[parentArrayIndex].minimum = numDeletedVertices;
            compArray.entries[parentArrayIndex].counter = 1;
            childArrayIndex = parentArrayIndex+1;
            nextChildIndex = parentArrayIndex+2;
        } else {
            done = true;
        }
    }
    __syncthreads();

    if (done) {return 1;}
    __syncthreads();

    while (true) {
        __syncthreads();
        if (threadIdx.x==0) {
            select_comp2 = 0;
            ++num_components;
            compSize = 0;
            if (!done) {
                atomicAdd((int*)&compArray.entries[parentArrayIndex].counter, 1);
            }

            compArray.entries[childArrayIndex].index = parentArrayIndex;
            compArray.entries[childArrayIndex].counter = 1;
            if (minimum-numDeletedVertices>num_components) {
                compArray.entries[childArrayIndex].minimum = minimum-numDeletedVertices-num_components+1;
            } else {
                compArray.entries[childArrayIndex].minimum = 0;
                atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum, minimum);
                if (!done) {
                    atomicSub((int*)&compArray.entries[parentArrayIndex].counter, 1);
                }
                done = true;
                ++num_components;
            }
        }
        __syncthreads();
        
        bool enqueueSuccess;
        unsigned int numDeletedVertices2 = 0;
        if(checkThreshold(workList)) {
            startTime(ENQUEUE,blockCounters);
            enqueueSuccess = enqueue_connected_comp((INT_OR_SHORT*)vertexDegrees_s, (INT_OR_SHORT*)components, comp1, &compSize, done, workList, vertexNum, &numDeletedVertices2, childArrayIndex, compArray);
        } else  {
            enqueueSuccess = false;
        }
        __syncthreads();

        if(!enqueueSuccess) {
            startTime(PUSH_TO_STACK,blockCounters);
            pushStack_connected_comp(vertexNum, (INT_OR_SHORT*)vertexDegrees_s, (INT_OR_SHORT*)components, comp1, &compSize, done, &numDeletedVertices2, childArrayIndex, NULL, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, NULL, stackTop, false, compArray); 
            endTime(PUSH_TO_STACK,blockCounters);
            maxDepth(*stackTop, blockCounters);
            if (threadIdx.x==0 && *stackTop==stackSize-1) {
                exceedFlag = true;
                compArray.entries[childArrayIndex].minimum = 0;
                atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum, minimum);
                if (!done) {
                    atomicSub((int*)&compArray.entries[parentArrayIndex].counter, 1);
                }
                done = true;
                ++num_components;
            }
            __syncthreads();
            if (exceedFlag) {--(*stackTop);}
        } else {
            endTime(ENQUEUE,blockCounters);
        }
        __syncthreads();
        
        if(done) {break;}
        __syncthreads();
        
        if (threadIdx.x==0) {
            comp1 = comp2;
        }
        __syncthreads();

        for (unsigned int i = start; i < right+1 && !select_comp2; i+=blockDim.x) {
            if(components[i]>-1 && components[i] != comp1) {
                if(atomicCAS(&select_comp2,0,1) == 0) {
                    comp2 = components[i];                   
                }
            }
        }
        __syncthreads();
        
        if (threadIdx.x == 0) {
            if (!select_comp2) {
                done = true;
            }
            childArrayIndex = nextChildIndex;
            nextChildIndex = atomicAdd((int*)compArray.globalArrayIndex,1);
            if (nextChildIndex>=compArraySize) {
                done = true;
            }
        }
        __syncthreads();
    }
    return num_components;
}

__device__ unsigned int bfsCC_Param_Hybrid(unsigned int vertexNum, INT_OR_SHORT* vertexDegrees_s, CSRGraph graph, INT_OR_SHORT* shared_mem, int arrayIndex, unsigned int minimum, unsigned int* numDeletedVertices, CompArray compArray, WorkList<INT_OR_SHORT> workList, Counters* blockCounters, volatile INT_OR_SHORT * stackVertexDegrees, volatile unsigned int * stackNumDeletedVertices, volatile int * stackArrayIndex, int* stackTop, unsigned int stackSize, unsigned int compArraySize, unsigned int * k, unsigned int * kFound, unsigned int left, unsigned int right) {

    __shared__ int globIndex;
    __shared__ int num_components;
    __shared__ bool exceedFlag;
    __shared__ bool done;
    __shared__ int found_new_level;
    __shared__ int select_comp;
    __shared__ int parentArrayIndex;
    __shared__ int childArrayIndex;
    __shared__ int nextChildIndex;
    __shared__ int compSize;
    __shared__ int not_Clique_Cycle;
    __shared__ int compStartingVertexDegree;

    volatile INT_OR_SHORT* components = shared_mem;    
    unsigned int start = threadIdx.x + left;
    
    if (threadIdx.x == 0) {
        done = true;
    }
    __syncthreads();

    for(unsigned int vertex = threadIdx.x; vertex < graph.vertexNum; vertex+=blockDim.x) {
        if(vertexDegrees_s[vertex] > 0) {
            components[vertex] = 0;
            done = false;
        } else {
            components[vertex] = -1;
        }
    }
    __syncthreads();

    if (done) {return 0;}
    
    if (threadIdx.x == 0) {
        globIndex = atomicOr((int*)compArray.globalArrayIndex,0);
        num_components = 0;
        exceedFlag = false;
    }
    __syncthreads();

    if (globIndex+3>compArraySize) {return 1;}

    do {
        __syncthreads();
        if(threadIdx.x == 0) {
            select_comp = 0;
            not_Clique_Cycle = 0;
            ++num_components;
            compSize = 1;
            done = true;
        }
        __syncthreads();

        for (unsigned int i = start; i<right+1 && !select_comp; i+=blockDim.x) {
            if(components[i] == 0) {
                if(atomicCAS(&select_comp,0,1) == 0) {
                    components[i] = 1;
                    compStartingVertexDegree = vertexDegrees_s[i];
                }
            }
        }
        __syncthreads();

        do {
            __syncthreads();
            if (threadIdx.x == 0) {
                found_new_level = 0;
            }
             __syncthreads();
            for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                if(components[vertex] == 0) {
                    for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex+1]; ++edge) {
                        unsigned int neigh = graph.dst[edge];
                        if (vertexDegrees_s[neigh]>0) {
                            if(components[neigh] == 1) {
                                components[vertex] = 1;
                                atomicAdd(&compSize,1);
                                found_new_level = 1;
                                if (vertexDegrees_s[vertex]!=compStartingVertexDegree) {
                                    not_Clique_Cycle = 1;
                                }
                                break;
                            }
                        }
                    }
                }
            }
            __syncthreads();
        } while (found_new_level);

        if (!not_Clique_Cycle) {
            if (compStartingVertexDegree == 2) {
                *numDeletedVertices += (compSize+1)/2;
                if (threadIdx.x == 0) {
                    if (num_components>1) {
                        atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum,(compSize+1)/2); 
                    }
                    --num_components;
                }
            } else if (compStartingVertexDegree == compSize-1) {
                *numDeletedVertices += compSize-1;
                if (threadIdx.x == 0) {
                    if (num_components>1) {
                        atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum,compSize-1); 
                    }
                    --num_components;
                }
            } else {
                 __syncthreads();
                if (threadIdx.x == 0) {
                    not_Clique_Cycle = 1;
                }
            }
        }
        __syncthreads();

        for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
            if(components[vertex] == 0) {
                done = false;
                break;
            }
        }
        __syncthreads();
        
        if (!not_Clique_Cycle) {
            if (!done) {
                for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                    if(components[vertex] > 0){
                        components[vertex] = -1;
                        vertexDegrees_s[vertex] = -1;
                    }
                }
                __syncthreads();
                continue;
            }

            if (num_components==0) {return 0;}
            
            if (threadIdx.x == 0) {
                int theArrayIndex = 0;
                int numDelVer = 0;
                unsigned int compMin = *k+1;
                unsigned int iterationCounter = 0;
                int parentIndex = parentArrayIndex;
                while (true) {
                    if (theArrayIndex>-1) {
                        if (iterationCounter>0) {
                            compMin = atomicMin((int*)&compArray.entries[theArrayIndex].minimum, numDelVer);
                            if (compMin<=numDelVer) {
                                break;
                            }
                            parentIndex = compArray.entries[theArrayIndex].index;
                        }
                        atomicSub((int*)&compArray.entries[parentIndex].minimum, compMin-numDelVer);
                        theArrayIndex = compArray.entries[parentIndex].index;
                        numDelVer = compArray.entries[parentIndex].minimum;
                    } else {
                        if(numDelVer<=*k) {
                            atomicOr(kFound,1);
                        }
                        // For Debugging Purposes
                        //printf("numDel = %d\n",numDelVer);
                        break;
                    }
                    ++iterationCounter;
                }
            }
            __syncthreads();
            return num_components+1; //although num_components maybe 1, it will run on the compArray
        }
        __syncthreads();
        
        if (num_components == 1) {
            if (done) {break;}
            __syncthreads();
            if(threadIdx.x == 0) {
                parentArrayIndex = atomicAdd((int*)compArray.globalArrayIndex,3);
                if (parentArrayIndex<compArraySize-2) {
                    compArray.entries[parentArrayIndex].index = arrayIndex;
                    compArray.entries[parentArrayIndex].minimum = *numDeletedVertices+*k+1;
                    childArrayIndex = parentArrayIndex+1;
                    nextChildIndex = parentArrayIndex+2;
                } else {
                    done = true;
                }
            }
            __syncthreads();
            if (done) {break;}
        } else {
            if (threadIdx.x == 0) {
                childArrayIndex = nextChildIndex;
                nextChildIndex = atomicAdd((int*)compArray.globalArrayIndex,1);
                if (nextChildIndex>=compArraySize) {
                    done = true;
                }
            }
        }
        __syncthreads();
        
        if (done) {
            for(unsigned int vertex = start; vertex<right+1; vertex+=blockDim.x) {
                if(components[vertex] == 1 || components[vertex] == 0) {
                    components[vertex] = vertexDegrees_s[vertex];
                    atomicAdd(&compSize,1);
                }
            }
        } else {
            for(unsigned int vertex = start; vertex<right+1; vertex+=blockDim.x) {
                if(components[vertex] == 1) {
                    components[vertex] = vertexDegrees_s[vertex];
                }
            }
        }
        __syncthreads();

        if(threadIdx.x == 0) {
            compArray.entries[childArrayIndex].index = parentArrayIndex;
            if (minimum>*numDeletedVertices+num_components) {
                compArray.entries[childArrayIndex].minimum = (compSize-1<minimum-*numDeletedVertices-num_components+1)?compSize-1:minimum-*numDeletedVertices-num_components+1;
                atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum,compArray.entries[childArrayIndex].minimum);
            } else {
                compArray.entries[childArrayIndex].minimum = 0;
                atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum, *k+1);
                done = true;
                ++num_components;
            }
        }
        __syncthreads();
        
        if (threadIdx.x==0) {
            if (done) {
                atomicSub((int*)&compArray.entries[parentArrayIndex].minimum, *k+1);
            }
        }
        __syncthreads();
 
        bool enqueueSuccess;
        unsigned int numDeletedVertices2 = 0;
        if(checkThreshold(workList)) {
            startTime(ENQUEUE,blockCounters);
            enqueueSuccess = enqueue((INT_OR_SHORT*)components, workList, vertexNum, &numDeletedVertices2, childArrayIndex);
        } else  {
            enqueueSuccess = false;
        }
        __syncthreads();

        if(!enqueueSuccess) {
            startTime(PUSH_TO_STACK,blockCounters);
            pushStack(vertexNum, (INT_OR_SHORT*)components, &numDeletedVertices2, childArrayIndex, NULL, stackVertexDegrees, stackNumDeletedVertices, stackArrayIndex, NULL, stackTop, false);        
            endTime(PUSH_TO_STACK,blockCounters);
            maxDepth(*stackTop, blockCounters);
            if (threadIdx.x==0 && *stackTop==stackSize-1) {
                exceedFlag = true;
                compArray.entries[childArrayIndex].minimum = 0;
                atomicAdd((int*)&compArray.entries[parentArrayIndex].minimum, minimum);
                if (!done) {
                    atomicSub((int*)&compArray.entries[parentArrayIndex].counter, 1);
                }
                done = true;
                ++num_components;
            }
            __syncthreads();
            if (exceedFlag) {--(*stackTop);}
        } else {
            endTime(ENQUEUE,blockCounters);
        }
        __syncthreads();

        if (!done) {
            for(unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x) {
                if(components[vertex] > 0){
                    components[vertex] = -1;
                }
            }
        }
        __syncthreads();

    } while(!done);
 
    return num_components;
}

__device__ unsigned int highDegreeReductionRule(unsigned int vertexNum, INT_OR_SHORT *vertexDegrees_s, CSRGraph graph, INT_OR_SHORT * shared_mem, unsigned int numDeletedVertices, unsigned int minimum, unsigned int left, unsigned int right) {

    __shared__ unsigned int numberDeleted_s;
    // __shared__ bool graphHasChanged;

    volatile INT_OR_SHORT * markedForDeletion = shared_mem;
    if (threadIdx.x==0){
        numberDeleted_s = 0;
    }
    unsigned int start = threadIdx.x + left;
    // do{
        volatile INT_OR_SHORT * vertexDegrees_v = vertexDegrees_s;
        __syncthreads();
        
        for (unsigned int vertex = start ; vertex < right+1; vertex += blockDim.x){
            markedForDeletion[vertex] = 0;
        }
        // if (threadIdx.x==0){
        //     graphHasChanged = false;
        // }
        
        // __syncthreads();

        for (unsigned int vertex = start ; vertex < right+1; vertex+=blockDim.x){
            INT_OR_SHORT degree = vertexDegrees_v[vertex];
            if (degree > 0 && degree + numDeletedVertices + numberDeleted_s >= minimum){
                markedForDeletion[vertex]=1;
            }
        }
        __syncthreads();
        
        for (unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x){
            if(markedForDeletion[vertex]){ 
                // graphHasChanged = true;
                vertexDegrees_v[vertex] = -1;
                atomicAdd(&numberDeleted_s,1);
            }
        }
        
        __syncthreads();
                    
        for (unsigned int vertex = start ; vertex < right+1; vertex+=blockDim.x){
            if(markedForDeletion[vertex]){ 
                for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex + 1]; edge++){
                    unsigned int neighbor = graph.dst[edge];
                    if (vertexDegrees_v[neighbor] > 0) {
                        ATOMIC_TYPE(atomicSub)(&vertexDegrees_s[neighbor],1);
                    }
                }
            }
        }
    
    // }while(graphHasChanged);

    __syncthreads();

    return numberDeleted_s;
}


__device__ unsigned int triangleReductionRule(unsigned int vertexNum, INT_OR_SHORT *vertexDegrees_s, CSRGraph graph, INT_OR_SHORT* shared_mem, unsigned int left, unsigned int right) {
    
    __shared__ unsigned int numberDeleted;
    // __shared__ bool graphHasChanged;
    
    volatile INT_OR_SHORT * markedForDeletion = shared_mem;
    if (threadIdx.x==0){
        numberDeleted = 0;
        //printf("triangle\n");
    }
    unsigned int start = threadIdx.x + left;
    // do{
        volatile INT_OR_SHORT * vertexDegrees_v = vertexDegrees_s;
        __syncthreads();

        for (unsigned int vertex = start ; vertex < right+1; vertex += blockDim.x){
            markedForDeletion[vertex] = 0;
        }

        // if (threadIdx.x==0){
        //     graphHasChanged = false;
        // }
        
        __syncthreads();
        
        for (unsigned int vertex = start ; vertex < right+1; vertex+=blockDim.x){
            
            INT_OR_SHORT degree = vertexDegrees_v[vertex];
            if (degree == 2){
                unsigned int neighbor1, neighbor2;
                bool foundNeighbor1 = false, keepNeighbors = false;
                for(unsigned int edge = graph.srcPtr[vertex] ; edge < graph.srcPtr[vertex + 1]; ++edge) {
                    unsigned int neighbor = graph.dst[edge];
                    INT_OR_SHORT neighborDegree = vertexDegrees_v[neighbor];
                    if(neighborDegree>0){
                        if(neighborDegree == 1 || neighborDegree == 2 && neighbor < vertex){
                            keepNeighbors = true;
                            break;
                        } else if(!foundNeighbor1){
                            foundNeighbor1 = true;
                            neighbor1 = neighbor;
                        } else {
                            neighbor2 = neighbor;    
                            break;
                        }
                    }
                }

                if(!keepNeighbors) {
                    bool found = binarySearch(graph.dst, graph.srcPtr[neighbor2], graph.srcPtr[neighbor2 + 1] - 1, neighbor1);
                    if(found){
                        // Triangle Found
                        markedForDeletion[neighbor1] = true;
                        markedForDeletion[neighbor2] = true;
                        break;
                    }
                }
            }
        }
        
        __syncthreads();
        
        for (unsigned int vertex = start; vertex < right+1; vertex+=blockDim.x){
            if(markedForDeletion[vertex]){ 
                // graphHasChanged = true;
                vertexDegrees_v[vertex] = -1;
                atomicAdd(&numberDeleted,1);
            }
        }
        
        __syncthreads();
        
        for (unsigned int vertex = start ; vertex < right+1; vertex+=blockDim.x){
            if(markedForDeletion[vertex]){ 
                for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex + 1]; edge++){
                    unsigned int neighbor = graph.dst[edge];
                    if (vertexDegrees_v[neighbor] > 0){
                        ATOMIC_TYPE(atomicSub)(&vertexDegrees_s[neighbor],1);
                    }
                }
            }
        }
    
    // }while(graphHasChanged);

    __syncthreads();

    return numberDeleted;
}

__device__ void findMaxDegree(unsigned int vertexNum, unsigned int *maxVertex, INT_OR_SHORT *maxDegree, INT_OR_SHORT *vertexDegrees_s, INT_OR_SHORT * shared_mem, unsigned int left, unsigned int right) {
    *maxVertex = 0;
    *maxDegree = 0;
    unsigned int start = threadIdx.x + left;
    for(unsigned int vertex = start; vertex < right+1; vertex += blockDim.x) {
        INT_OR_SHORT degree = vertexDegrees_s[vertex];
        if(degree > *maxDegree){ 
            *maxVertex = vertex;
            *maxDegree = degree;
        }
    }

    // Reduce max degree
    INT_OR_SHORT * vertex_s = shared_mem;
    INT_OR_SHORT * degree_s = &shared_mem[blockDim.x];
    __syncthreads(); 

    #if USE_SHORT_DEGREE
    vertex_s[threadIdx.x] = threadIdx.x;
    #else
    vertex_s[threadIdx.x] = *maxVertex;
    #endif

    degree_s[threadIdx.x] = *maxDegree;
    __syncthreads();

    for(unsigned int stride = blockDim.x/2; stride > 0; stride /= 2) {
        if(threadIdx.x < stride) {
            if(degree_s[threadIdx.x] < degree_s[threadIdx.x + stride]){
                degree_s[threadIdx.x] = degree_s[threadIdx.x + stride];
                vertex_s[threadIdx.x] = vertex_s[threadIdx.x + stride];
            }
        }
        __syncthreads();
    }
    
    *maxDegree = degree_s[0];
    
    #if USE_SHORT_DEGREE
    __shared__ unsigned int tempMaxVertex;
    if (threadIdx.x == vertex_s[0]) {
        tempMaxVertex = *maxVertex;
    }
    __syncthreads();
    *maxVertex = tempMaxVertex;
    
    #else
    *maxVertex = vertex_s[0];
    
    #endif
    __syncthreads();
}

__device__ unsigned int RemoveMaxApproximateMVC(CSRGraph graph,  INT_OR_SHORT* vertexDegrees_s, INT_OR_SHORT* vertexDegrees_s2,INT_OR_SHORT* vertexDegrees_s3, unsigned int minimum_s, int left, int right){

    unsigned int numDeletedVertices=0;
    for (unsigned int vertex = threadIdx.x + left; vertex < right+1; vertex += blockDim.x){
        vertexDegrees_s2[vertex] = vertexDegrees_s[vertex];
    }
    __syncthreads();
    unsigned int maxVertex;
    INT_OR_SHORT maxDegree;
    do{
        //reduction rules
        unsigned int iterationCounter = 0, numDeletedVerticesLeaf, numDeletedVerticesTriangle, numDeletedVerticesHighDegree, numDeletedVerticesInducedClique;
        do {
            numDeletedVerticesLeaf = leafReductionRule(graph.vertexNum, vertexDegrees_s2, graph, vertexDegrees_s3, left, right);
            numDeletedVertices += numDeletedVerticesLeaf;
            if(iterationCounter==0 || numDeletedVerticesLeaf>0 || numDeletedVerticesHighDegree>0 || numDeletedVerticesInducedClique>0) {
                numDeletedVerticesTriangle = triangleReductionRule(graph.vertexNum, vertexDegrees_s2, graph, vertexDegrees_s3, left, right);
                numDeletedVertices += numDeletedVerticesTriangle;
            } else {
                numDeletedVerticesTriangle = 0;
            }
            if(iterationCounter==0 || numDeletedVerticesLeaf>0 || numDeletedVerticesTriangle>0 || numDeletedVerticesInducedClique>0) {
                numDeletedVerticesHighDegree = highDegreeReductionRule(graph.vertexNum, vertexDegrees_s2, graph, vertexDegrees_s3,numDeletedVertices,minimum_s, left, right);
                numDeletedVertices += numDeletedVerticesHighDegree;
            } else {
                numDeletedVerticesHighDegree = 0;
            }
            if(iterationCounter==0 || numDeletedVerticesLeaf>0 || numDeletedVerticesTriangle>0 || numDeletedVerticesHighDegree>0) {
                numDeletedVerticesInducedClique = inducedCliqueReductionRule(graph.vertexNum, vertexDegrees_s2, graph, vertexDegrees_s3, left, right);
                numDeletedVertices += numDeletedVerticesInducedClique;
            } else {
                numDeletedVerticesInducedClique = 0;
            }
            ++iterationCounter;
        } while(numDeletedVerticesTriangle>0 || numDeletedVerticesHighDegree>0 || numDeletedVerticesInducedClique>0);
        
        __syncthreads();

        //find max and delete it 
        findMaxDegree(graph.vertexNum, &maxVertex, &maxDegree, vertexDegrees_s2, vertexDegrees_s3, left, right);     
        deleteMaxDegreeVertex(graph, vertexDegrees_s2, &numDeletedVertices, maxVertex);

    } while(maxDegree>0); 

    return numDeletedVertices;
}

__device__ unsigned int findNumOfEdges(unsigned int vertexNum, INT_OR_SHORT *vertexDegrees_s, INT_OR_SHORT * shared_mem, unsigned int left, unsigned int right) {

    int sumDegree = 0;
    unsigned int start = threadIdx.x + left;
    for(unsigned int vertex = start; vertex < right+1; vertex += blockDim.x) {
        int degree = vertexDegrees_s[vertex];
        if(degree > 0){
            sumDegree += degree;
        }
    }
    __syncthreads();
    INT_OR_SHORT* degree_s = shared_mem;
    
    #if USE_SHORT_DEGREE

    saveIntInShortArray(&degree_s[2*threadIdx.x], sumDegree);
    
    __syncthreads();

    for(unsigned int stride = blockDim.x; stride > 1; stride /= 2) {
        if(2*threadIdx.x < stride) {
            AddIntInShortArray(&degree_s[2*threadIdx.x],readIntFromShortArray(&degree_s[2*threadIdx.x+stride]));
        }
        __syncthreads();
    }
    return readIntFromShortArray(&degree_s[0])/2;

    #else
    
    degree_s[threadIdx.x] = sumDegree;
    
    __syncthreads();
    
    for(unsigned int stride = blockDim.x/2; stride > 0; stride /= 2) {
        if(threadIdx.x < stride) {
            degree_s[threadIdx.x] += degree_s[threadIdx.x + stride];
        }
        __syncthreads();
    }
    return degree_s[0]/2;
    
    #endif
}

#undef INT_OR_SHORT
#undef ATOMIC_TYPE(base)
#endif
